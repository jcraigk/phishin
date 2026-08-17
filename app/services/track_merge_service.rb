# Merges two adjacent tracks into one: concatenates their audio with ffmpeg,
# backs up both sources, keeps the first track's record and removes the second,
# and carries over every piece of derived data (likes, tags, jam start, playlist
# entries) with the second track's timestamps rebased onto the merged clock.
#
# The inverse of TrackSplitService. Written for sandwiches stored as two tracks
# ("Hold Your Head Up" + "Terrapin > Hold Your Head Up"), which should be one
# ("HYHU > Terrapin > HYHU").
#
# Gaps are NOT recomputed here; lib/tasks/sandwich_scan.rake runs GapService once
# per show after all of its merges are in, scoped to the songs involved.
class TrackMergeService < ApplicationService
  param :track
  option :second
  option :title
  option :dry_run, default: -> { false }

  OUTPUT_DIR = Rails.root.join("tmp/track_merges")
  BACKUP_DIR = Rails.root.join("tmp/track_merge_backups")

  class Error < StandardError; end
  class MissingAudioError < Error; end
  class TitleError < Error; end
  class NotAdjacentError < Error; end

  def call
    validate!
    @first_title = track.title
    @second_title = second.title
    download_sources
    render_merged

    return result if dry_run

    backup_sources
    apply!
    attach_audio
    result
  ensure
    @first_file&.close!
    @second_file&.close!
  end

  private

  def label
    "#{track.show.date} #{track.title} + #{second.title}"
  end

  def validate!
    raise TitleError, "#{label}: merged title is blank" if title.to_s.strip.empty?

    unless track.show_id == second.show_id
      raise NotAdjacentError, "#{label}: tracks are in different shows"
    end
    unless track.set == second.set
      raise NotAdjacentError,
            "#{label}: tracks are in different sets (#{track.set} and #{second.set})"
    end
    unless second.position == track.position + 1
      raise NotAdjacentError,
            "#{label}: tracks are not adjacent (positions #{track.position} " \
            "and #{second.position})"
    end
    [ track, second ].each do |t|
      if t.missing_audio? || !t.mp3_audio.attached?
        raise MissingAudioError, "#{label}: #{t.title.inspect} has no audio attached"
      end
    end
  end

  def download_sources
    @first_file = download(track, "first")
    @second_file = download(second, "second")
  end

  def download(record, which)
    file = Tempfile.new([ "track_#{record.id}_#{which}", ".mp3" ], binmode: true)
    record.mp3_audio.blob.download { |chunk| file.write(chunk) }
    file.flush
    file
  rescue ActiveStorage::FileNotFoundError
    raise MissingAudioError,
          "#{label}: blob #{record.mp3_audio.blob.key} is not in storage"
  end

  def first_duration_s
    @first_duration_s ||= probe(@first_file.path, "duration").to_f
  end

  def second_duration_s
    @second_duration_s ||= probe(@second_file.path, "duration").to_f
  end

  def bitrate
    @bitrate ||= begin
      raw = probe(@first_file.path, "bit_rate")
      /\A\d+\z/.match?(raw) ? "#{(raw.to_i / 1000.0).round}k" : "192k"
    end
  end

  def probe(path, entry)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format=#{entry}",
      "-of", "csv=p=0", path
    )
    raise Error, "ffprobe failed for #{label}: #{err}" unless status.success?
    out.strip
  end

  def output_path
    @output_path ||= OUTPUT_DIR.join("#{track.show.date}_#{track.slug}_merged.mp3")
  end

  # Butt joined, no crossfade: the two tracks are consecutive audio from one
  # recording, so anything else would invent a transition.
  def render_merged
    FileUtils.mkdir_p(OUTPUT_DIR)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error",
      "-i", @first_file.path, "-i", @second_file.path,
      "-filter_complex",
      "[0:a]aresample=44100[a];[1:a]aresample=44100[b];[a][b]concat=n=2:v=0:a=1[out]",
      "-map", "[out]", "-map_metadata", "0", "-id3v2_version", "3",
      "-b:a", bitrate, output_path.to_s
    )
    raise Error, "ffmpeg failed for #{label}: #{err}" unless status.success?
  end

  def backup_sources
    FileUtils.mkdir_p(BACKUP_DIR)
    @backup_paths = [ [ track, @first_file ], [ second, @second_file ] ].map do |t, file|
      path = BACKUP_DIR.join("#{t.show.date}_#{t.slug}_#{t.mp3_audio.blob.key}.mp3")
      FileUtils.cp(file.path, path)
      path.to_s
    end
  end

  def apply!
    ActiveRecord::Base.transaction do
      @offset = first_duration_s
      move_likes
      move_tags
      move_jam_start
      move_playlist_entries
      rewrite_first
      @removed_id = second.id
      second.reload.destroy!
      close_position_gap
      reslug_duplicate_titles
    end
  end

  # A listener who liked either half liked the sandwich, but a user who liked
  # both must not end up with two likes on one track.
  def move_likes
    existing = track.likes.pluck(:user_id).to_set
    @likes_moved = 0
    second.likes.find_each do |like|
      next if existing.include?(like.user_id)
      like.update!(likable: track)
      existing << like.user_id
      @likes_moved += 1
    end
  end

  # Timestamps on the second track are relative to its own start, which in the
  # merged track begins where the first one ended.
  def move_tags
    @tags_moved = 0
    @notes = []
    seen = track.track_tags.filter_map do |tt|
      tt.tag_id if tt.starts_at_second.nil? && tt.ends_at_second.nil?
    end.to_set
    second.track_tags.find_each do |tt|
      if tt.starts_at_second.nil? && tt.ends_at_second.nil?
        next tt.destroy! if seen.include?(tt.tag_id)
        seen << tt.tag_id
      end
      tt.update!(
        track:,
        starts_at_second: tt.starts_at_second && (tt.starts_at_second + @offset).round,
        ends_at_second: tt.ends_at_second && (tt.ends_at_second + @offset).round
      )
      @tags_moved += 1
    end
  end

  def move_jam_start
    return if track.jam_starts_at_second.present?
    jam = second.jam_starts_at_second
    return if jam.nil?
    track.update!(jam_starts_at_second: (jam + @offset).round)
  end

  # An entry for the second half now points at the merged track. Where a
  # playlist held both halves back to back, the pair becomes one entry so the
  # playlist plays the same audio without repeating it.
  def move_playlist_entries
    @playlist_entries = 0
    second.playlist_tracks.includes(:playlist).find_each do |entry|
      prev = entry.playlist.playlist_tracks
                  .find_by(position: entry.position - 1, track_id: track.id)
      if prev && whole_track?(prev) && whole_track?(entry)
        entry.destroy!
        @notes << "playlist '#{entry.playlist.name}' held both halves; " \
                  "collapsed into one entry"
        next
      end
      entry.update!(
        track:,
        starts_at_second: (entry.starts_at_second || 0) + @offset.round,
        ends_at_second: entry.ends_at_second && (entry.ends_at_second + @offset).round
      )
      @playlist_entries += 1
    end
  end

  def whole_track?(entry)
    entry.starts_at_second.to_i.zero? && entry.ends_at_second.nil?
  end

  # Slug is parked, not computed: the merged title may already belong to another
  # track in the show. reslug_duplicate_titles assigns the real one.
  def rewrite_first
    track.title = title.strip
    track.songs = merged_songs
    track.slug = "tmp-#{track.id}-merge-#{SecureRandom.hex(4)}"
    track.save!
  end

  # The union of both tracks' songs, in playing order. A sandwich carries the
  # outer song once, the same as one that was never split.
  def merged_songs
    (track.songs.to_a + second.songs.to_a).uniq
  end

  def close_position_gap
    track.show.tracks.reload
         .where(position: (second.position)..)
         .order(position: :asc)
         .each { it.update!(position: it.position - 1) }
  end

  def reslug_duplicate_titles
    @reslugged = []
    siblings = track.show.tracks.reload.order(:position)
                    .select { track.title.casecmp?(it.title) }
    return if siblings.empty?

    was = siblings.to_h { [ it.id, it.slug ] }
    # Two phases: (show_id, slug) is unique, and the final slugs permute among
    # these same rows, so assigning them directly would collide with a row that
    # has not been renumbered yet.
    siblings.each_with_index do |sibling, i|
      sibling.update_columns(slug: "tmp-#{track.id}-#{i}-#{SecureRandom.hex(4)}")
    end
    siblings.each do |sibling|
      sibling.generate_slug(force: true)
      sibling.save!
      next if sibling.slug == was[sibling.id] || sibling.id == track.id
      @reslugged << { track_id: sibling.id, from: was[sibling.id], to: sibling.slug }
    end
  end

  def attach_audio
    track.mp3_audio.attach(
      io: File.open(output_path), filename: track.friendly_filename,
      content_type: "audio/mpeg"
    )
    track.reload
    track.process_mp3_audio
  end

  def result
    {
      track_id: track.id,
      removed_track_id: (@removed_id unless dry_run),
      label:,
      title: title.strip,
      first_title: @first_title,
      second_title: @second_title,
      first_duration_s: first_duration_s.round(1),
      second_duration_s: second_duration_s.round(1),
      merged_duration_s: (first_duration_s + second_duration_s).round(1),
      output_path: output_path.to_s,
      backup_paths: @backup_paths || [],
      song_ids: (dry_run ? (track.songs + second.songs).uniq : track.songs).map(&:id),
      url: (track.url unless dry_run),
      likes_moved: @likes_moved.to_i,
      tags_moved: @tags_moved.to_i,
      playlist_entries: @playlist_entries.to_i,
      reslugged: @reslugged || [],
      notes: @notes || [],
      applied: !dry_run
    }
  end
end
