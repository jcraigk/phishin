# Moves the point where one track ends and the next begins, without losing a
# sample of what was on either side.
#
# The fix for a boundary an importer or a scan put slightly wrong: a song's
# first note stranded on the tail of the track above it, or the last chord of
# one song opening the next. Positive delta_s grows the first track and shrinks
# the second; negative does the reverse.
#
# Concat-then-recut, deliberately. Joining the pair is usually a stream copy,
# and the single cut that follows is the only lossy pass; trimming one side and
# re-encoding the other would be two. This is an archive, so the fewest
# decode/encode passes wins. The cut reuses TrackSplitService.filters so a
# boundary render is byte-for-byte the way a split renders.
#
# Titles are the one piece of metadata this job will write, and only when the
# caller asks: a boundary that was in the wrong place is usually in the wrong
# place because the titles were wrong too, and the user asked to fix both
# before committing rather than in two separate edits. Positions, songs, likes,
# tags and playlist entries are still untouched.
#
# Songs are deliberately NOT repointed from a new title. That association drives
# gaps, debut and bustout tags and stats; rewriting it from free text is a
# different edit. The payload reports which renamed sides no longer match any of
# their songs so the UI can say so, and nothing more.
#
# Gaps are not recomputed, matching split's behavior - the editor's gapsStale
# banner covers a published show.
class Admin::ShiftBoundaryJob
  include Sidekiq::Job

  # Both sides must survive the move with real audio on them. A boundary pushed
  # nearer than this to either far edge is a mis-typed delta, not an edit.
  MIN_PART_S = 1.0

  class NoNextTrackError < StandardError; end
  class MissingAudioError < StandardError; end
  class DeltaOutOfRangeError < StandardError; end
  class BlankTitleError < StandardError; end

  # titles is nil to rename nothing, or a hash with either or both of "first"
  # and "second". A missing key leaves that side alone; a blank value is a
  # mistake, not a request to clear a title, so it raises.
  def perform(track_id, admin_job_id, delta_s, apply, titles = nil)
    @first = Track.find(track_id)
    @delta_s = delta_s.to_f
    @apply = apply
    @titles = normalize_titles(titles)
    admin_job = AdminJob.find(admin_job_id)

    @admin_job = admin_job

    admin_job.run! do
      find_second!
      ensure_audio!
      ensure_titles_present!
      ensure_delta_in_stored_range!
      join
      ensure_delta_in_range!
      render_sides
      store_renders(admin_job)
      apply! if apply?
      admin_job.payload.merge!(payload)
      admin_job.save!
    end
  end

  private

  attr_reader :first, :second, :delta_s, :titles

  def apply? = @apply

  # String keys, so the same hash survives a round trip through Sidekiq's JSON
  # and a direct call from a spec or a console. Nils are dropped here (a missing
  # side means "leave it alone"); blanks are kept so ensure_titles_present! can
  # name the offending side rather than silently ignoring it.
  def normalize_titles(raw)
    return nil if raw.blank?
    raw.to_h.transform_keys(&:to_s).slice("first", "second")
       .reject { |_side, title| title.nil? }
       .transform_values { it.is_a?(String) ? it.strip : it }
       .presence
  end

  # Checked before any ffmpeg work, so a typo costs no render time and leaves
  # nothing changed.
  def ensure_titles_present!
    return if titles.nil?
    blank = titles.select { |_side, title| title.blank? }.keys
    return if blank.empty?
    raise BlankTitleError,
          "blank title for #{blank.join(' and ')} track; " \
          "omit the key to leave a title unchanged"
  end

  def renames
    @renames ||= { first => titles&.dig("first"), second => titles&.dig("second") }
                 .compact
                 .reject { |track, title| track.title == title }
  end

  def show = first.show

  def find_second!
    @second = show.tracks.find_by(position: first.position + 1)
    return if @second
    raise NoNextTrackError,
          "#{show.date} #{first.title}: no track below position #{first.position}"
  end

  def ensure_audio!
    missing = [ first, second ].reject { it.mp3_audio.attached? }
    return if missing.empty?
    raise MissingAudioError,
          "no audio attached: #{missing.map { "#{show.date} #{it.title}" }.join(', ')}"
  end

  # The pair becomes one continuous file, exactly as it sounded end to end, and
  # the recut works from that. Always applied rather than dry run: a dry run
  # returns a Tempfile path whose finalizer deletes the file as soon as the
  # service is collected, and the recut needs the join to still be on disk. The
  # join writes nothing to the database either way, so an applied render is just
  # a durable one.
  def join
    @concat = TrackConcatService.call(tracks: [ first, second ])
    @joined_path = @concat[:output_path]
  end

  def first_duration_s = @concat[:source_durations].first

  def total_duration_s = @concat[:duration_s]

  # Where the boundary lands on the joined clock.
  def cut_s
    @cut_s ||= (first_duration_s + delta_s).round(2)
  end

  def allowed_range
    [ (MIN_PART_S - first_duration_s).round(1),
      (total_duration_s - MIN_PART_S - first_duration_s).round(1) ]
  end

  # Screened off the stored durations first, so an impossible delta costs no
  # ffmpeg time. The probed check below is the authority, but the two agree
  # except where a stored duration has drifted from its file.
  def ensure_delta_in_stored_range!
    low = (MIN_PART_S - first.duration.to_i / 1000.0).round(1)
    high = (second.duration.to_i / 1000.0 - MIN_PART_S).round(1)
    return if delta_s >= low && delta_s <= high
    raise DeltaOutOfRangeError, out_of_range_message(low, high)
  end

  def ensure_delta_in_range!
    return if cut_s >= MIN_PART_S && cut_s <= total_duration_s - MIN_PART_S
    raise DeltaOutOfRangeError, out_of_range_message(*allowed_range)
  end

  def out_of_range_message(low, high)
    "delta of #{delta_s.round(1)}s moves the boundary outside the audio; " \
      "allowed range is #{low}s to #{high}s"
  end

  def output_dir = Rails.root.join("tmp/track_boundaries")

  def side_paths
    @side_paths ||= [ 1, 2 ].map do |n|
      output_dir.join("#{show.date}_#{first.slug}_boundary#{n}.mp3")
    end
  end

  def bitrate
    @bitrate ||= begin
      out, _err, status = Open3.capture3(
        "ffprobe", "-v", "error", "-show_entries", "format=bit_rate",
        "-of", "csv=p=0", @joined_path
      )
      raw = status.success? ? out.strip : ""
      /\A\d+\z/.match?(raw) ? "#{(raw.to_i / 1000.0).round}k" : "192k"
    end
  end

  def render_sides
    FileUtils.mkdir_p(output_dir)
    render(TrackSplitService.filters(start_s: 0.0, end_s: cut_s), side_paths[0])
    render(TrackSplitService.filters(start_s: cut_s), side_paths[1])
  end

  def render(filters, out_path)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", "-i", @joined_path,
      "-af", filters.join(","), "-map_metadata", "0", "-id3v2_version", "3",
      "-b:a", bitrate, out_path.to_s
    )
    raise TrackConcatService::Error, "ffmpeg failed for #{show.date}: #{err}" unless status.success?
  end

  # Both sides, so an admin auditions the end of the first track and the start
  # of the second before committing - hearing the seam from one side only is
  # what let a bad boundary through in the first place.
  def store_renders(admin_job)
    admin_job.payload["audio_paths"] = [
      AdminJobAudio.store(admin_job, side_paths[0].to_s, index: 0),
      AdminJobAudio.store(admin_job, side_paths[1].to_s, index: 1)
    ]
  end

  # Metadata in a transaction, audio after it: the same division CombineTracksJob
  # and TrackSplitService already use, and not a stylistic one. An attach on a
  # persisted record defers the upload to after_commit, so a track whose audio is
  # attached INSIDE a transaction has no file on disk when process_mp3_audio
  # reads it back to probe the duration - ActiveStorage::FileNotFoundError, every
  # time. The rename cannot ride along in the attach's transaction because the
  # attach cannot be in one.
  #
  # A rename outliving a failed edit is prevented by ordering instead, and more
  # completely than a shared transaction would manage: every check and both
  # ffmpeg renders finish before apply! is entered, so the ways this job fails
  # (a missing track, missing audio, an out-of-range delta, a blank title, an
  # ffmpeg error) all raise while the titles are still untouched. The transaction
  # around the renames themselves keeps the pair atomic with the reslug, so a
  # unique-slug violation on the second title cannot leave the first renamed.
  #
  # Backups are taken first, before any write, because back_up names its file
  # after the CURRENT slug - the name for the audio the track held before this
  # edit. Renames are saved before attach for the reason the combine job saves
  # metadata first: TrackAudioReplacer reloads the track and derives the blob
  # filename from friendly_filename, so the new audio only carries the new title
  # if the title is already committed to the row.
  def apply!
    @backup_paths = [ back_up(first), back_up(second) ]
    ActiveRecord::Base.transaction { rename! }
    attach(first, side_paths[0])
    attach(second, side_paths[1])
    shift_timestamps
  end

  # THE TWO SIDES DO NOT SHARE A DELTA, and getting that backwards is how a
  # boundary shift quietly moves every tag on the show's second half.
  #
  # Lay the pair on the joined clock: the first track is [0, first_duration_s),
  # the second is [first_duration_s, total), and the new boundary is at cut_s.
  #
  #   FIRST  keeps its origin. Its audio is now [0, cut_s) on the same clock it
  #          always had, so nothing on it moved: delta 0. Its DURATION changed,
  #          which is the part that matters - a negative delta_s shortens it, and
  #          a tag that lived in the seconds handed to the second track now
  #          points past the end of the first and orphans.
  #   SECOND moved. A moment that sat at x on the second track's own clock sat at
  #          first_duration_s + x on the joined clock, and now sits at
  #          (first_duration_s + x) - cut_s, which is x - delta_s. So its delta
  #          is MINUS delta_s: growing the first track by 5s pulls everything on
  #          the second back by 5.
  #
  # Audio that crossed the boundary carries its tags nowhere: this moves windows
  # on one track's clock and never REPARENTS one to the other side, which is a
  # different rule (see the note at the bottom of TimestampShifter). A window
  # stranded by the move is orphaned with its numbers intact for an admin to
  # repoint, rather than guessed onto a track it was never measured against.
  def shift_timestamps
    @shifts = {
      first => TimestampShifter.call(
        track: first.reload, delta_s: 0.0, new_duration_s: new_durations[0],
        reason: "shift_boundary"
      ),
      second => TimestampShifter.call(
        track: second.reload, delta_s: -delta_s, new_duration_s: new_durations[1],
        reason: "shift_boundary"
      )
    }
  end

  def new_durations
    @new_durations ||= [ cut_s, total_duration_s - cut_s ].map { it.round(1) }
  end


  def rename!
    return if renames.empty?
    @titles_before = renames.keys.to_h { [ it.id, it.title ] }
    @titles_changed = renames.map do |track, title|
      { "track_id" => track.id, "from" => track.title, "to" => title }
    end
    renames.each { |track, title| track.update!(title:) }
    reslug!
  end

  # A published show keeps its slugs so existing track URLs stay valid, matching
  # the rename in ApiV2::Admin::Tracks and the merge in CombineTracksJob.
  def slug_frozen? = show.published?

  # TrackSlugGenerator numbers duplicate titles by POSITION order, so a track's
  # slug is a function of its SIBLINGS' titles, and a rename can permute slugs
  # among rows that were never named in the request. Every track sharing a title
  # this edit touched - the titles being replaced as much as the ones replacing
  # them - can move, so all of them are regenerated together.
  #
  # Two phases, the same approach TrackSplitService#reslug_duplicate_titles
  # uses: (show_id, slug) is unique and the final slugs permute among these same
  # rows, so assigning them directly would collide with a row not yet
  # renumbered. Everyone parks on a temp slug first, then each is regenerated.
  def reslug!
    return if slug_frozen?
    affected = affected_siblings
    was = affected.to_h { [ it.id, it.slug ] }
    affected.each_with_index do |track, i|
      track.update_columns(slug: "tmp-#{first.id}-#{i}-#{SecureRandom.hex(4)}")
    end
    affected.each do |track|
      track.generate_slug(force: true)
      track.save!
      next if track.slug == was[track.id]
      reslugged << { "track_id" => track.id, "from" => was[track.id], "to" => track.slug }
    end
  end

  # Titles are compared case-insensitively because the generator slugs through
  # downcase: "Ghost" and "ghost" are one duplicate group as far as slugs go.
  def affected_siblings
    titles_touched = (renames.values + @titles_before.values).map(&:downcase).uniq
    show.tracks.reload.order(:position)
        .select { titles_touched.include?(it.title.downcase) }
  end

  def reslugged = @reslugged ||= []

  def back_up(record)
    AudioBackup.store(record, operation: "shift_boundary")
  end

  # Through TrackAudioReplacer for the blob safety it already carries:
  # process_mp3_audio's ID3 rewrite REPLACES the attachment, and a replacement
  # purges the blob it displaced, so the blob handed in must be one nothing else
  # points at. The throwaway blob is purged once the replacer has copied out.
  def attach(record, path)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: File.open(path),
      filename: record.friendly_filename,
      content_type: "audio/mpeg"
    )
    TrackAudioReplacer.call(track: record.reload, blob:)
    blob.purge
  end

  def payload
    {
      "track_id" => first.id,
      "second_track_id" => second.id,
      "delta_s" => delta_s.round(2),
      "cut_s" => cut_s,
      "reencoded" => @concat[:reencoded],
      "total_duration_s" => total_duration_s,
      "source_durations" => @concat[:source_durations],
      "new_durations" => new_durations,
      "backup_paths" => @backup_paths
    }.compact.merge(rename_payload)
  end

  # Only reported when something was actually renamed, so a shift with no titles
  # keeps the payload it had before this feature existed.
  def rename_payload
    return {} if @titles_changed.blank?
    {
      "titles_changed" => @titles_changed,
      "reslugged" => reslugged,
      "slug_frozen" => slug_frozen?,
      "song_drift" => song_drift
    }
  end

  # The UI's warning, not a block: the user chose to rename titles without
  # repointing tracks.songs, so a renamed side whose new title no longer matches
  # any of its songs is flagged for an admin to fix in the Songs control. A
  # segue title ("Tweezer > Ghost") legitimately matches neither song, which is
  # exactly why this warns rather than refusing.
  def song_drift
    renames.filter_map do |track, title|
      next if track.songs.any? { title.casecmp?(it.title) }
      { "track_id" => track.id, "title" => title,
        "song_titles" => track.songs.map(&:title) }
    end
  end
end
