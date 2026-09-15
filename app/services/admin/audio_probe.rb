module Admin::AudioProbe
  class Error < StandardError; end

  def self.duration_s(path)
    out, err, ok = capture(path, "format=duration")
    raise Error, "ffprobe failed for #{path}: #{err}" unless ok
    out.to_f
  end

  def self.read(path, entry)
    out, _err, ok = capture(path, entry)
    ok ? out.presence : nil
  end

  def self.read_audio_stream(path, entry)
    out, _err, ok = capture(path, entry, "-select_streams", "a:0")
    ok ? out.lines.first.to_s.strip.split(",").first.presence : nil
  end

  def self.capture(path, entry, *options)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", *options, "-show_entries", entry, "-of", "csv=p=0", path.to_s
    )
    [ out.strip, err, status.success? ]
  end
  private_class_method :capture
end
