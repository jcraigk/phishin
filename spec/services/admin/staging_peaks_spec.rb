require "rails_helper"

RSpec.describe Admin::StagingPeaks do
  let(:dir) { Pathname.new(Dir.mktmpdir) }
  let(:audio) { dir.join("tone.flac") }
  let(:out) { dir.join("peaks.bin") }

  after { FileUtils.rm_rf(dir) }

  def render(source, secs, gain: 1.0)
    system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "#{source}:duration=#{secs}",
           "-af", "volume=#{gain}", "-c:a", "flac", audio.to_s, exception: true)
  end

  it "writes one byte per hundredth of a second" do
    render("sine=frequency=440", 3)

    count = described_class.generate(audio, out)

    expect(count).to be_within(2).of(300)
    expect(out.size).to eq(count)
  end

  it "stores linear amplitude so a full-scale tone reads full, a quiet one reads low, and silence reads zero" do
    render("sine=frequency=440", 1, gain: 8)
    tone = described_class.generate(audio, out).then { File.binread(out).bytes }
    render("sine=frequency=440", 1, gain: 0.8)
    quiet = described_class.generate(audio, out).then { File.binread(out).bytes }
    render("anullsrc=r=44100", 1)
    silent = described_class.generate(audio, out).then { File.binread(out).bytes }

    expect(tone.max).to be_between(240, 255)
    expect(quiet.max).to be_between(20, 32)
    expect(silent.max).to eq(0)
  end

  it "raises when ffmpeg cannot read the file" do
    File.write(audio, "not audio")

    expect { described_class.generate(audio, out) }.to raise_error(Admin::StagingPeaks::Error)
  end
end
