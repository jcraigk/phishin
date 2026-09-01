# One copy of a track's audio, taken right before an edit rewrites it. The
# filename carries everything there is to know - show date, track slug, the
# operation about to happen, and when - so recovery is a directory listing
# rather than a database lookup.
module AudioBackup
  DIR = Rails.root.join("tmp/audio_backups")

  # Copies the track's attached audio down from storage.
  def self.store(track, operation:)
    return nil unless track.mp3_audio.attached?
    path = path_for(track, operation)
    File.open(path, "wb") do |file|
      track.mp3_audio.blob.download { |chunk| file.write(chunk) }
    end
    path.to_s
  end

  # For callers that already hold the bytes on disk.
  def self.store_file(source_path, track:, operation:)
    path = path_for(track, operation)
    FileUtils.cp(source_path, path)
    path.to_s
  end

  def self.path_for(track, operation)
    FileUtils.mkdir_p(DIR)
    stamp = Time.current.utc.strftime("%Y%m%d-%H%M%S")
    DIR.join("#{track.show.date}_#{track.slug}_#{operation}_#{stamp}.mp3")
  end
end
