require "rails_helper"
require "rake"

RSpec.describe "gapless_scan" do # rubocop:disable RSpec/DescribeClass
  before do
    next if Rake::Task.task_defined?("gapless_scan:run")
    Rake::Task.define_task(:environment)
    load Rails.root.join("lib/tasks/gapless_scan.rake")
  end

  # Undeclared padding decodes as a flat, very low floor - a couple of counts of
  # dither - and the performance starts abruptly above it. The level it starts
  # at is what varies between tracks, and what the detector must not depend on.
  def build_mp3(path, pad_level:, music_level:, pad_s: 0.022)
    FileUtils.mkdir_p(File.dirname(path))
    pad = "sine=frequency=60:duration=#{pad_s}:sample_rate=44100," \
          "volume=#{pad_level / 32_768.0}"
    music = "sine=frequency=440:duration=2:sample_rate=44100," \
            "volume=#{music_level / 32_768.0}"
    system("ffmpeg", "-y", "-v", "error",
           "-f", "lavfi", "-i", pad, "-f", "lavfi", "-i", music,
           "-filter_complex",
           "[0:a]aformat=channel_layouts=stereo[a];" \
           "[1:a]aformat=channel_layouts=stereo[b];[a][b]concat=n=2:v=0:a=1[out]",
           "-map", "[out]", "-b:a", "192k", path.to_s, exception: true)
    path
  end

  describe ".head_plateau_s" do
    it "finds the edge when the performance starts loud" do
      path = build_mp3(Rails.root.join("tmp/spec/head_loud.mp3"),
                       pad_level: 2, music_level: 8_000)
      expect(GaplessScan.head_plateau_s(path)).to be_within(0.003).of(0.022)
    end

    # The case the fixed threshold ladder missed: a track whose music starts
    # only a little above its padding never reaches the higher rungs, so they
    # all land deep in the performance and never agree on the edge.
    it "finds the edge when the performance starts quiet" do
      path = build_mp3(Rails.root.join("tmp/spec/head_quiet.mp3"),
                       pad_level: 2, music_level: 130)
      expect(GaplessScan.head_plateau_s(path)).to be_within(0.003).of(0.022)
    end

    it "leaves a track alone when there is no padding to cut" do
      path = build_mp3(Rails.root.join("tmp/spec/head_none.mp3"),
                       pad_level: 6_000, music_level: 8_000, pad_s: 0.5)
      expect(GaplessScan.head_plateau_s(path)).to be_nil
    end

    # A track that opens straight into a note has no flat floor to measure, so
    # the window fills with the performance and the threshold scales off it.
    # Read that way the edge lands inside the note, and the cut takes its
    # attack with it - 980 tracks were measured that way before this guard.
    it "refuses a track whose head is a rising note rather than padding" do
      path = Rails.root.join("tmp/spec/head_attack.mp3")
      FileUtils.mkdir_p(path.dirname)
      system("ffmpeg", "-y", "-v", "error",
             "-f", "lavfi",
             "-i", "sine=frequency=440:duration=2:sample_rate=44100",
             "-af", "afade=t=in:st=0:d=0.03,volume=0.5",
             "-b:a", "192k", path.to_s, exception: true)
      expect(GaplessScan.head_plateau_s(path)).to be_nil
    end
  end
end
