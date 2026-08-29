require "rails_helper"

RSpec.describe Admin::ArchiveItem do
  let(:identifier) { "ph2024-07-19.flac16" }
  let(:metadata) do
    {
      metadata: { description: "<p>Source: Schoeps MK4</p><br>Taper: X" },
      files: [
        { name: "ph2024-07-19d1t02.flac", format: "Flac" },
        { name: "ph2024-07-19d1t01.flac", format: "Flac" },
        { name: "ph2024-07-19d1t01.mp3", format: "VBR MP3" },
        { name: "ph2024-07-19d1t01.png", format: "PNG" },
        { name: "ph2024-07-19.ffp", format: "Flac FingerPrint" }
      ]
    }
  end

  before { allow(Typhoeus).to receive(:get) { instance_double(Typhoeus::Response, code: 200, body: metadata.to_json) } }

  it "picks the lossless files in name order and ignores everything else" do
    item = described_class.new(identifier)
    expect(item.files.map { it["name"] })
      .to eq([ "ph2024-07-19d1t01.flac", "ph2024-07-19d1t02.flac" ])
  end

  it "falls back to mp3 when the item has no lossless audio" do
    metadata[:files].reject! { it[:format] == "Flac" }
    expect(described_class.new(identifier).files.map { it["name"] })
      .to eq([ "ph2024-07-19d1t01.mp3" ])
  end

  it "raises when the item has no audio at all" do
    metadata[:files] = [ { name: "x.png", format: "PNG" } ]
    expect { described_class.new(identifier).files }.to raise_error(described_class::NoAudioError)
  end

  it "raises when the item does not exist" do
    allow(Typhoeus).to receive(:get).and_return(instance_double(Typhoeus::Response, code: 200, body: "{}"))
    expect { described_class.new("nope").files }.to raise_error(described_class::NotFoundError)
  end

  it "strips html from the description" do
    expect(described_class.new(identifier).description).to eq("Source: Schoeps MK4\nTaper: X")
  end

  it "links to the details page" do
    expect(described_class.new(identifier).details_url).to eq("https://archive.org/details/ph2024-07-19.flac16")
  end

  describe "#download_to" do
    let(:dir) { Rails.root.join("tmp/spec/archive_item") }

    before { FileUtils.rm_rf(dir) }

    it "fetches each chosen file with curl into the directory" do
      item = described_class.new(identifier)
      allow(item).to receive(:system) do |*args|
        File.write(args[-2], "flac bytes")
        true
      end
      paths = item.download_to(dir)
      expect(paths.map { File.basename(it) }).to eq([ "ph2024-07-19d1t01.flac", "ph2024-07-19d1t02.flac" ])
      expect(File.read(paths.first)).to eq("flac bytes")
      expect(item).to have_received(:system).with(
        "curl", "-sfL", "--retry", "2", "-o", anything,
        "https://archive.org/download/ph2024-07-19.flac16/ph2024-07-19d1t01.flac"
      )
    end

    it "raises after three failed attempts" do
      item = described_class.new(identifier)
      allow(item).to receive(:system).and_return(false)
      expect { item.download_to(dir) }.to raise_error(described_class::DownloadError)
    end
  end
end
