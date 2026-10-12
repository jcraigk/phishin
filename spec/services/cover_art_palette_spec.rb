require "rails_helper"
require "mini_magick"

RSpec.describe CoverArtPalette do
  let(:dir) { Pathname.new(Dir.mktmpdir) }

  after { FileUtils.rm_rf(dir) }

  def blob_of(color)
    path = dir.join("#{color.delete('#')}.png")
    MiniMagick.convert do |convert|
      convert.size("64x64")
      convert << "xc:#{color}"
      convert << path.to_s
    end
    ActiveStorage::Blob.create_and_upload!(io: File.open(path), filename: path.basename.to_s, content_type: "image/png")
  end

  def strongest_bin(palette)
    palette["histogram"].each_with_index.max_by(&:first).last
  end

  it "puts a blue image's colour in the blue part of the wheel" do
    palette = described_class.call(blob_of("#2050e0"))
    expect(strongest_bin(palette) * described_class::BIN_DEGREES).to be_within(30).of(225)
  end

  it "puts a red image's colour at the top of the wheel" do
    palette = described_class.call(blob_of("#e02020"))
    expect(strongest_bin(palette)).to eq(0)
  end

  it "scores a vivid image as colourful and a grey one as not" do
    expect(described_class.call(blob_of("#20c040"))["colorfulness"]).to be > 0.5
    expect(described_class.call(blob_of("#808080"))["colorfulness"]).to be < 0.05
  end

  it "caches the result on the blob so each cover is measured once" do
    blob = blob_of("#e0a020")
    described_class.call(blob)
    allow(MiniMagick::Image).to receive(:read).and_call_original
    described_class.call(blob.reload)
    expect(MiniMagick::Image).not_to have_received(:read)
    expect(blob.metadata["palette"]).to include("histogram", "colorfulness")
  end
end
