module Admin::AudioProbe
  class Error < StandardError; end

  def self.duration_s(path)
    out, err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-show_entries", "format=duration",
      "-of", "csv=p=0", path.to_s
    )
    raise Error, "ffprobe failed for #{path}: #{err}" unless status.success?
    out.strip.to_f
  end
end
