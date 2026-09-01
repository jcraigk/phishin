module AudioBackup
  DIR = Rails.root.join("tmp/audio_backups")

  def self.store(track, operation:)
    return nil unless track.mp3_audio.attached?
    path = path_for(track, operation)
    File.open(path, "wb") do |file|
      track.mp3_audio.blob.download { |chunk| file.write(chunk) }
    end
    path.to_s
  end

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
