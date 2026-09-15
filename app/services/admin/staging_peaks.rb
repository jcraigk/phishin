class Admin::StagingPeaks
  RATE = 100
  SAMPLE_RATE = 8000
  FRAME = SAMPLE_RATE / RATE

  class Error < StandardError; end

  def self.generate(audio_path, out_path)
    new(audio_path, out_path).generate
  end

  def initialize(audio_path, out_path)
    @audio_path = audio_path
    @out_path = out_path
  end

  def generate
    out, err, status = Open3.capture3("ffmpeg", "-v", "error", "-i", @audio_path.to_s, "-af", filter, "-f", "null", "-")
    raise Error, "ffmpeg peaks failed: #{err}" unless status.success?
    bytes = out.each_line.filter_map { |line| level_to_byte(line) }
    raise Error, "no peaks produced" if bytes.empty?
    File.binwrite(@out_path, bytes.pack("C*"))
    bytes.size
  end

  private

  def filter
    [
      "aresample=#{SAMPLE_RATE}",
      "aformat=channel_layouts=mono",
      "asetnsamples=n=#{FRAME}",
      "astats=metadata=1:reset=1",
      "ametadata=mode=print:key=lavfi.astats.Overall.Peak_level:file=-"
    ].join(",")
  end

  def level_to_byte(line)
    return nil unless line.start_with?("lavfi.astats.Overall.Peak_level=")
    value = line.split("=", 2).last.strip
    return 0 if value == "-inf" || value.empty?
    amplitude = 10**(value.to_f / 20)
    (amplitude.clamp(0.0, 1.0) * 255).round
  end
end
