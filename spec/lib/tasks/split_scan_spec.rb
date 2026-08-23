require "rails_helper"
require "rake"

RSpec.describe "split_scan" do # rubocop:disable RSpec/DescribeClass
  before do
    next if Rake::Task.task_defined?("split_scan:run")
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/split_scan.rake")
  end

  # Tone with a run of digital silence bolted on the end, which is the shape a
  # track takes when the split dropped its final audio and padded the length.
  def build_mp3(path, silence_s)
    FileUtils.mkdir_p(File.dirname(path))
    inputs = [
      "-f", "lavfi", "-i", "sine=frequency=440:duration=3:sample_rate=44100"
    ]
    filter = "[0:a]aformat=channel_layouts=stereo"
    if silence_s.positive?
      inputs += [ "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo:d=#{silence_s}" ]
      filter = "[0:a]aformat=channel_layouts=stereo[a];[a][1:a]concat=n=2:v=0:a=1"
    end
    system("ffmpeg", "-y", "-v", "error", *inputs,
           "-filter_complex", "#{filter}[out]", "-map", "[out]",
           "-b:a", "192k", path.to_s, exception: true)
    path
  end

  describe ".trailing_zeros_s" do
    it "measures a long run of digital silence" do
      path = build_mp3(Rails.root.join("tmp/spec/split_padded.mp3"), 0.8)
      expect(SplitScan.trailing_zeros_s(File.binread(path)))
        .to be_within(0.05).of(0.8)
    end

    it "reads near zero for a track that ends on its audio" do
      path = build_mp3(Rails.root.join("tmp/spec/split_clean.mp3"), 0.0)
      expect(SplitScan.trailing_zeros_s(File.binread(path))).to be < 0.05
    end

    # The scan reads a byte range off the end rather than the whole file, so
    # what matters is that the answer does not depend on how much was read.
    it "measures the same however much of the tail is read" do
      path = build_mp3(Rails.root.join("tmp/spec/split_padded.mp3"), 0.8)
      whole = File.binread(path)
      tail = whole.byteslice(-SplitScan::TAIL_BYTES..) || whole
      half = whole.byteslice(-(SplitScan::TAIL_BYTES / 2)..) || whole
      expect(SplitScan.trailing_zeros_s(half))
        .to be_within(0.001).of(SplitScan.trailing_zeros_s(tail))
    end

    # A read that lands entirely inside the silence can only report how much it
    # read, which would understate the run.
    it "declines to guess when every frame it read was silent" do
      path = build_mp3(Rails.root.join("tmp/spec/split_padded.mp3"), 0.8)
      whole = File.binread(path)
      expect(SplitScan.trailing_zeros_s(whole.byteslice(-8_192..))).to be_nil
    end

    it "returns nil when the bytes do not decode" do
      expect(SplitScan.trailing_zeros_s("not an mp3")).to be_nil
    end
  end

  describe ".suspect?" do
    it "ignores the encoder padding every mp3 carries" do
      expect(SplitScan.suspect?(0.03)).to be false
    end

    it "flags a run far longer than any encoder writes" do
      expect(SplitScan.suspect?(0.7)).to be true
    end

    it "ignores a missing measurement" do
      expect(SplitScan.suspect?(nil)).to be false
    end
  end
end
