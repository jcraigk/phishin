class BulkAudioMatcher < ApplicationService
  option :show
  option :blobs

  def call
    {
      matches:,
      unmatched_filenames: filenames - matches.map { |m| m[:filename] },
      unmatched_tracks: unmatched_track_payloads
    }
  end

  private

  def matches
    @matches ||= begin
      claimed = []
      filenames.filter_map do |filename|
        track = match_track(filename, claimed)
        next if track.nil?
        claimed << track.id
        match_payload(filename, track)
      end.sort_by { |m| m[:position] }
    end
  end

  def match_track(filename, claimed)
    by_position(filename, claimed) || by_song(filename, claimed)
  end

  def by_position(filename, claimed)
    position = leading_position(filename)
    return nil if position.nil?
    tracks_by_position[position].then { |track| claimed.include?(track&.id) ? nil : track }
  end

  def leading_position(filename)
    match = filename.match(/\A(?:I{1,3}-|E\d?-)?(\d{1,3})[\s._-]/i)
    match && match[1].to_i
  end

  def by_song(filename, claimed)
    song = filename_matcher.matches[filename]
    return nil if song.nil?
    tracks_by_song[song.id].find { |track| !claimed.include?(track.id) }
  end

  def match_payload(filename, track)
    {
      signed_id: blobs_by_filename[filename].signed_id,
      url: Rails.application.routes.url_helpers.rails_blob_path(
        blobs_by_filename[filename], only_path: true
      ),
      filename:,
      track_id: track.id,
      position: track.position,
      title: track.title,
      duration: duration_ms(blobs_by_filename[filename]),
      action: track.mp3_audio.attached? ? "replace" : "fill"
    }
  end

  def duration_ms(blob)
    return nil unless blob.service.respond_to?(:path_for)
    out, _err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format=duration",
      "-of", "csv=p=0", blob.service.path_for(blob.key)
    )
    status.success? ? (out.to_f * 1000).round : nil
  end

  def unmatched_track_payloads
    matched = matches.map { |m| m[:track_id] }
    tracks.reject { |track| matched.include?(track.id) }.map do |track|
      { track_id: track.id, position: track.position, title: track.title }
    end
  end

  def tracks
    @tracks ||= show.tracks.order(:position).includes(:songs, mp3_audio_attachment: :blob).to_a
  end

  def tracks_by_position
    @tracks_by_position ||= tracks.index_by(&:position)
  end

  def tracks_by_song
    @tracks_by_song ||= tracks.each_with_object(Hash.new { |h, k| h[k] = [] }) do |track, acc|
      track.songs.each { |song| acc[song.id] << track }
    end
  end

  def blobs_by_filename
    @blobs_by_filename ||= blobs.index_by { |blob| Show.original_filename(blob) }
  end

  def filenames
    @filenames ||= blobs_by_filename.keys.sort
  end

  def filename_matcher
    @filename_matcher ||= ShowImporter::FilenameMatcher.new(filenames:)
  end
end
