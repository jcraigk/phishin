# Splits a track whose title combines multiple songs with ">"
# into one track per song, cutting the MP3 at the given offsets.
# Split times mark where each subsequent song begins, in seconds.
class TrackSplitter < ApplicationService
  param :track
  option :split_at_seconds
  option :dry_run, default: -> { false }

  def call
    ensure_valid_input
    return segments if dry_run

    split_audio_files
    persist_segments
    post_process
    @tracks
  ensure
    remove_temp_files
  end

  def segments
    @segments ||= segment_titles.each_with_index.map do |title, idx|
      {
        title:,
        song: song_for(title),
        starts_at: idx.zero? ? 0 : split_at_seconds[idx - 1],
        ends_at: split_at_seconds[idx]
      }
    end
  end

  private

  def segment_titles
    @segment_titles ||= track.title.split(">").map(&:strip)
  end

  def ensure_valid_input
    raise "Track has no audio!" if track.missing_audio?

    expected = segment_titles.size - 1
    if split_at_seconds.size != expected
      raise "Expected #{expected} split time(s) for title #{track.title.inspect}, " \
            "got #{split_at_seconds.size}"
    end

    unless split_at_seconds.all?(Numeric) && split_at_seconds.each_cons(2).all? { |a, b| a < b }
      raise "Split times must be ascending numbers of seconds!"
    end

    if split_at_seconds.first <= 0 || split_at_seconds.last >= track.duration / 1000
      raise "Split times must fall within track duration " \
            "(#{track.duration / 1000} seconds)!"
    end

    segments
  end

  def song_for(title)
    Song.find_by("lower(title) = :t OR lower(alias) = :t", t: title.downcase) ||
      raise("No song found matching #{title.inspect}")
  end

  def split_audio_files
    @source_file = Tempfile.new([ "track_#{track.id}_source", ".mp3" ])
    @source_file.binmode
    @source_file.write(track.mp3_audio.download)
    @source_file.rewind

    segments.each_with_index do |segment, idx|
      path = segment_audio_path(idx)
      args = [ "-i", @source_file.path, "-ss", segment[:starts_at].to_s ]
      args += [ "-to", segment[:ends_at].to_s ] if segment[:ends_at]
      _stdout, stderr, status = Open3.capture3 \
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        *args, "-c", "copy", path
      unless status.success? && File.exist?(path) && File.size(path).positive?
        raise "ffmpeg failed on segment #{idx + 1}: #{stderr}"
      end
    end
  end

  def persist_segments
    @original_jam_start = track.jam_starts_at_second
    ActiveRecord::Base.transaction do
      shift_subsequent_tracks
      @tracks = [ update_original_track ] + create_new_tracks
      relocate_track_tags
      relocate_jam_start
    end
  end

  def shift_subsequent_tracks
    track.show.tracks
         .where("position > ?", track.position)
         .order(position: :desc)
         .each { |t| t.update!(position: t.position + segments.size - 1) }
  end

  def update_original_track
    adjust_audio_counters_for_song_changes
    track.title = segments.first[:title]
    track.songs = [ segments.first[:song] ]
    track.jam_starts_at_second = nil
    track.generate_slug(force: true)
    track.save!
    track.mp3_audio.attach \
      io: File.open(segment_audio_path(0)),
      filename: track.friendly_filename,
      content_type: "audio/mpeg"
    track
  end

  def create_new_tracks
    segments.each_with_index.drop(1).map do |segment, idx|
      new_track = Track.create!(
        show: track.show,
        title: segment[:title],
        songs: [ segment[:song] ],
        position: track.position + idx,
        set: track.set,
        audio_status: track.audio_status
      )
      new_track.mp3_audio.attach \
        io: File.open(segment_audio_path(idx)),
        filename: new_track.friendly_filename,
        content_type: "audio/mpeg"
      new_track
    end
  end

  def relocate_track_tags
    track.track_tags.reload.each do |track_tag|
      next if track_tag.starts_at_second.nil?
      idx = segment_index_at(track_tag.starts_at_second)
      next if idx.zero?
      offset = segments[idx][:starts_at]
      track_tag.update!(
        track: @tracks[idx],
        starts_at_second: track_tag.starts_at_second - offset,
        ends_at_second: track_tag.ends_at_second && track_tag.ends_at_second - offset
      )
    end
  end

  def relocate_jam_start
    return if @original_jam_start.nil?
    idx = segment_index_at(@original_jam_start)
    @tracks[idx].update!(jam_starts_at_second: @original_jam_start - segments[idx][:starts_at])
  end

  # Track's after_create hook increments tracks_with_audio_count for each new
  # track's song, but nothing decrements when songs are removed from the
  # original track, so balance that here.
  def adjust_audio_counters_for_song_changes
    return if track.missing_audio?
    removed = track.songs - [ segments.first[:song] ]
    added = [ segments.first[:song] ] - track.songs
    removed.each { |song| song.decrement!(:tracks_with_audio_count) }
    added.each { |song| song.increment!(:tracks_with_audio_count) }
  end

  def segment_index_at(second)
    segments.rindex { |segment| second >= segment[:starts_at] } || 0
  end

  def post_process
    @tracks.each(&:process_mp3_audio)
    refresh_playlist_tracks
    GapService.call(track.show, update_previous: true)
  end

  # Playlist tracks cache duration from their track, which shrinks
  # when the original track becomes just the first segment.
  def refresh_playlist_tracks
    track.playlist_tracks.reload.each(&:save!)
  end

  def segment_audio_path(idx)
    "#{Rails.root}/tmp/track_#{track.id}_segment_#{idx}.mp3"
  end

  def remove_temp_files
    @source_file&.close!
    @segments&.each_index do |idx|
      path = segment_audio_path(idx)
      File.delete(path) if File.exist?(path)
    end
  end
end
