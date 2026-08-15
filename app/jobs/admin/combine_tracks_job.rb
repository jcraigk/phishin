# Merges a track into the one above it: one title joined by a segue, one set of
# songs, one audio file, one row.
#
# The audio is the reason this is a job rather than the inline endpoint it used
# to be. Combining two tracks that BOTH have audio has to JOIN them - the old
# inline path kept only the first track's file and destroyed the second's, which
# silently deleted archive audio with no backup. Joining takes an ffmpeg render,
# which is too slow for a request, so combine now runs preview-then-apply like
# trim and split: preview renders the join so an admin can audition the seam,
# apply commits it.
#
# The destroyed track's likes, tags and playlist entries are UNIONED onto the
# survivor before it is destroyed. Track's associations are all
# dependent: :destroy, so anything left behind would be deleted with the row.
class Admin::CombineTracksJob
  include Sidekiq::Job

  class NoPreviousTrackError < StandardError; end

  def perform(track_id, admin_job_id, apply)
    @track = Track.find(track_id)
    @apply = apply
    admin_job = AdminJob.find(admin_job_id)

    admin_job.run! do
      find_previous!
      render_join
      store_render(admin_job)
      apply! if apply?
      admin_job.payload.merge!(payload)
      admin_job.save!
    end
  end

  private

  attr_reader :track, :previous

  def apply? = @apply

  def show = track.show

  def find_previous!
    @previous = show.tracks.find_by(position: track.position - 1)
    return if @previous
    raise NoPreviousTrackError,
          "#{show.date} #{track.title}: no track above position #{track.position}"
  end

  def joining_audio?
    track.mp3_audio.attached? && previous.mp3_audio.attached?
  end

  # Rendered for a preview too: auditioning the seam is the whole point of
  # previewing a combine, and the render is what an apply would attach.
  def render_join
    return unless joining_audio?
    @concat = TrackConcatService.call(tracks: [ previous, track ], dry_run: !apply?)
  end

  def store_render(admin_job)
    return unless @concat
    admin_job.payload["audio_paths"] =
      [ AdminJobAudio.store(admin_job, @concat[:output_path]) ]
  end

  def apply!
    # The second track's audio has to be captured before destroy! purges the
    # blob with the row, and the metadata has to be saved before the audio is
    # attached: TrackAudioReplacer reloads the track, which would drop an
    # unsaved title.
    stage_audio
    ActiveRecord::Base.transaction do
      merge_metadata
      absorb_likes
      absorb_track_tags
      absorb_playlist_tracks
      previous.save!
      track.destroy!
      renumber
    end
    absorb_audio
  end

  # Unchanged from the inline endpoint this replaces: the titles are joined by a
  # segue marker, the songs are unioned, and a published show keeps its slug so
  # existing track URLs stay valid.
  def merge_metadata
    previous.title = "#{previous.title} > #{track.title}"
    previous.generate_slug(force: true) unless show.published?
    previous.songs = (previous.songs + track.songs).uniq
  end

  # Both originals are captured here, before anything changes: destroy! purges
  # the second track's blob along with its row, and the survivor's slug is about
  # to become the merged one, which would misname a backup of the audio it held
  # BEFORE the merge. TrackAudioReplacer backs the survivor up too, but only
  # under its post-merge name; these are the ones that follow the convention.
  #
  # Also picks the local file the survivor's audio will come from, if any:
  #   both have audio - the joined render
  #   only the second - its backup, a byte-for-byte copy already on disk
  #   only the first  - nothing; the survivor keeps what it has
  #   neither         - nothing
  def stage_audio
    @backup_paths = [ previous, track ].select { it.mp3_audio.attached? }.map { back_up(it) }
    @source_path =
      if @concat
        @concat[:output_path]
      elsif track.mp3_audio.attached? && !previous.mp3_audio.attached?
        @backup_paths.last
      end
  end

  def absorb_audio
    return reprocess_survivor_audio if @source_path.nil?

    # TrackAudioReplacer copies the bytes into a blob of the track's own and
    # reprocesses duration, ID3 and waveform. The copy matters: process_mp3_audio's
    # ID3 rewrite REPLACES the attachment, and replacing purges the blob it
    # replaced, so the blob handed in must not be one anything else still points
    # at - hence a throwaway blob, purged once the replacer has copied out of it.
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(@source_path),
      filename: previous.friendly_filename,
      content_type: "audio/mpeg"
    )
    TrackAudioReplacer.call(track: previous.reload, blob:)
    blob.purge
  end

  def back_up(record)
    FileUtils.mkdir_p(TrackAudioReplacer::BACKUP_DIR)
    path = TrackAudioReplacer::BACKUP_DIR.join(
      "#{record.show.date}_#{record.slug}_#{record.mp3_audio.blob.key}.mp3"
    )
    File.open(path, "wb") do |file|
      record.mp3_audio.blob.download { |chunk| file.write(chunk) }
    end
    path.to_s
  end

  # Moved, not copied: the row is about to be destroyed and would take its likes
  # with it. A user who liked both tracks already has the survivor's like, and
  # (user, likable) is unique, so their second one is dropped rather than raising.
  def absorb_likes
    liked = previous.likes.pluck(:user_id).to_set
    @likes_moved = 0
    track.likes.find_each do |like|
      next if liked.include?(like.user_id)
      like.update!(likable: previous)
      liked << like.user_id
      @likes_moved += 1
    end
  end

  # Timestamped tags describe a moment in the audio, which now sits after the
  # first track's audio, so they are rebased onto the joined clock. Untimestamped
  # tags describe the whole recording, so a tag already on the survivor is
  # dropped rather than duplicated.
  def absorb_track_tags
    offset = @concat ? @concat[:source_durations].first.round : 0
    existing = previous.track_tags.where(starts_at_second: nil, ends_at_second: nil)
                       .pluck(:tag_id).to_set
    @tags_moved = 0
    track.track_tags.find_each do |track_tag|
      timestamped = track_tag.starts_at_second || track_tag.ends_at_second
      next if !timestamped && existing.include?(track_tag.tag_id)
      track_tag.update!(
        track: previous,
        starts_at_second: track_tag.starts_at_second&.+(offset),
        ends_at_second: track_tag.ends_at_second&.+(offset)
      )
      existing << track_tag.tag_id unless timestamped
      @tags_moved += 1
    end
  end

  # A playlist entry has to keep playing the same audio, so an excerpt of the
  # second track is rebased onto the joined clock the same way a tag is. An entry
  # covering the whole second track now needs an explicit start, or it would play
  # the survivor from the top.
  def absorb_playlist_tracks
    offset = @concat ? @concat[:source_durations].first.round : 0
    @playlist_entries = 0
    track.playlist_tracks.find_each do |entry|
      updates = { track: previous }
      if offset.positive?
        updates[:starts_at_second] = entry.starts_at_second.to_i + offset
        updates[:ends_at_second] = entry.ends_at_second&.+(offset)
      end
      entry.update!(updates)
      @playlist_entries += 1
    end
  end

  # Position is unique per show, so the rows park in the negative mirror of
  # their target before flipping positive. Same two-phase pass the tracks
  # endpoint uses after a destroy.
  def renumber
    show.tracks.reload.order(:position).each.with_index(1) do |t, index|
      t.update_columns(position: -index)
    end
    show.tracks.where(position: ...0).each do |t|
      t.update_columns(position: -t.position)
    end
  end

  # No new audio, but the survivor's title changed, so its ID3 tags are stale.
  # TrackAudioReplacer does this itself whenever it attaches.
  def reprocess_survivor_audio
    return unless previous.reload.mp3_audio.attached?
    previous.process_mp3_audio
  end

  def payload
    {
      "track_id" => previous.id,
      "destroyed_track_id" => (track.id if apply?),
      "joined_audio" => !@concat.nil?,
      "reencoded" => @concat&.dig(:reencoded),
      "duration_s" => @concat&.dig(:duration_s),
      "source_durations" => @concat&.dig(:source_durations),
      "backup_paths" => @backup_paths,
      "likes_moved" => @likes_moved,
      "tags_moved" => @tags_moved,
      "playlist_entries" => @playlist_entries
    }.compact
  end
end
