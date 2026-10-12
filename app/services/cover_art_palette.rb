class CoverArtPalette < ApplicationService
  BINS = 12
  BIN_DEGREES = 360 / BINS
  SAMPLE_SIZE = 48

  param :blob

  def call
    blob.metadata["palette"] || measure_and_cache
  end

  private

  def measure_and_cache
    palette = measure
    blob.update!(metadata: blob.metadata.merge("palette" => palette))
    palette
  end

  def measure
    histogram = Array.new(BINS, 0.0)
    chroma_total = 0.0
    pixels.each do |r, g, b|
      hue, chroma = hue_and_chroma(r, g, b)
      chroma_total += chroma
      histogram[(hue / BIN_DEGREES).floor % BINS] += chroma if hue
    end
    weight = histogram.sum
    {
      "histogram" => histogram.map { weight.zero? ? 0.0 : (it / weight).round(4) },
      "colorfulness" => (chroma_total / pixels.size).round(4)
    }
  end

  def pixels
    @pixels ||= begin
      image = MiniMagick::Image.read(blob.download)
      image.resize("#{SAMPLE_SIZE}x#{SAMPLE_SIZE}!")
      image.get_pixels.flatten(1)
    end
  end

  def hue_and_chroma(r, g, b)
    max = [ r, g, b ].max
    min = [ r, g, b ].min
    chroma = (max - min) / 255.0
    return [ nil, chroma ] if chroma.zero?
    sector =
      if max == r then ((g - b) / (max - min).to_f) % 6
      elsif max == g then ((b - r) / (max - min).to_f) + 2
      else ((r - g) / (max - min).to_f) + 4
      end
    [ sector * 60, chroma ]
  end
end
