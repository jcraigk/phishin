# Pairs a folder of uploaded mp3s with the tracks of a show that already exists.
#
# The import path (ShowImporter::Matcher) builds tracks from Phish.net and hangs
# filenames off them. This is the other direction: the tracks are already here,
# and a better source has turned up for a show whose audio is partial. It never
# writes anything, so the editor can show the plan before an admin commits to it.
class BulkAudioMatcher < ApplicationService
  option :show
  option :blobs

  def call
    {
      matches:,
      unmatched_filenames: filenames - matches.map { |m| m[:filename] },
      tracks_without_audio: audioless_track_payloads
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
      end
    end
  end

  # Position first: a source folder that numbers its files is stating the answer
  # outright, and a numbered file that lands on a real position beats any title
  # guess. Song matching is the fallback for folders that only name the songs.
  def match_track(filename, claimed)
    by_position(filename, claimed) || by_song(filename, claimed)
  end

  def by_position(filename, claimed)
    position = leading_position(filename)
    return nil if position.nil?
    tracks_by_position[position].then { |track| claimed.include?(track&.id) ? nil : track }
  end

  # Filenames lead with the track number ("07 Ghost.mp3", "I-03_Bathtub Gin.mp3"),
  # optionally behind a roman-numeral set prefix the importer also understands.
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
      filename:,
      track_id: track.id,
      position: track.position,
      title: track.title,
      action: track.mp3_audio.attached? ? "replace" : "fill"
    }
  end

  def audioless_track_payloads
    tracks.reject { |track| track.mp3_audio.attached? }.map do |track|
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

  # Read the raw column: ActiveStorage sanitizes ">" out of Filename#to_s, and the
  # segue markers it destroys are exactly what the title heuristics match on.
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
