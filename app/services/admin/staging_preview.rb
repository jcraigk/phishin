class Admin::StagingPreview
  BITRATE = "128k".freeze

  class Error < StandardError; end

  def self.generate(audio_path, out_path)
    _out, err, status = Open3.capture3(
      "ffmpeg", "-y", "-v", "error", "-i", audio_path.to_s,
      "-codec:a", "libmp3lame", "-b:a", BITRATE, out_path.to_s
    )
    raise Error, "ffmpeg preview failed: #{err}" unless status.success?
  end
end
