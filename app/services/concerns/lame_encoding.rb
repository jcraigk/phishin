module LameEncoding
  extend ActiveSupport::Concern

  # Both scales run best-to-worst, so 0 is the highest setting of each.
  # -V 0 averages ~246kbps, matching the ~250kbps the catalog's existing
  # LAME-encoded tracks were made at; -q 0 is the slowest, most accurate
  # encoder. VBR also gets a Xing header rather than an Info one, and that is
  # what carries the gapless delay and padding counts.
  VBR_QUALITY = "0".freeze
  ALGORITHM_QUALITY = "0".freeze

  private

  def render_via_lame(out_path, ffmpeg_args)
    Tempfile.create([ "lame_render", ".wav" ]) do |wav|
      run_ffmpeg(ffmpeg_args + [ "-f", "wav", "-acodec", "pcm_s16le", wav.path ])
      run_lame(wav.path, out_path)
    end
  end

  def run_ffmpeg(args)
    _out, err, status = Open3.capture3("ffmpeg", "-y", "-v", "error", *args)
    raise render_error, "ffmpeg failed for #{label}: #{err}" unless status.success?
  end

  def run_lame(wav_path, out_path)
    _out, err, status = Open3.capture3(
      "lame", "--quiet", "-V", VBR_QUALITY, "-q", ALGORITHM_QUALITY,
      wav_path, out_path.to_s
    )
    raise render_error, "lame failed for #{label}: #{err}" unless status.success?
  end

  def render_error
    self.class.const_defined?(:Error) ? self.class.const_get(:Error) : StandardError
  end
end
