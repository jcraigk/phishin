require "rails_helper"

RSpec.describe Admin::StagingPreview do
  let(:dir) { Pathname.new(Dir.mktmpdir) }
  let(:audio) { dir.join("timeline.flac") }
  let(:out) { dir.join("preview.mp3") }

  after { FileUtils.rm_rf(dir) }

  before do
    system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=30",
           "-c:a", "flac", audio.to_s, exception: true)
  end

  it "encodes the timeline as an mp3" do
    described_class.generate(audio, out)
    expect(mp3_frame_sync?(File.binread(out))).to be(true)
  end

  it "keeps the timeline's length so preview seconds line up with track edges" do
    described_class.generate(audio, out)
    expect(Admin::AudioProbe.duration_s(out)).to be_within(0.05).of(30.0)
  end

  it "raises when ffmpeg fails" do
    expect { described_class.generate(dir.join("missing.flac"), out) }.to raise_error(described_class::Error)
  end
end
