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

  describe ".partition_runs" do
    def row(position, preceded:, followed:)
      { "date" => "2001-05-23", "set" => "1", "position" => position,
        "preceded_in_set" => preceded, "followed_in_set" => followed }
    end

    it "groups adjacent joined tracks into one run" do
      rows = [ row(1, preceded: false, followed: true),
               row(2, preceded: true, followed: true),
               row(3, preceded: true, followed: false) ]
      runs, solo = GaplessScan.partition_runs(rows)
      expect(runs.map { |r| r.map { it["position"] } }).to eq([ [ 1, 2, 3 ] ])
      expect(solo).to be_empty
    end

    # Why a held-back track is dropped whole rather than trimmed at the tail:
    # once it is out of the list its neighbours are no longer adjacent, so they
    # fall out to solo trims instead of being crossfaded across a gap where the
    # missing track still sits untouched.
    it "does not join tracks left non-adjacent by a held-back one" do
      rows = [ row(1, preceded: false, followed: true),
               row(3, preceded: true, followed: false) ]
      runs, solo = GaplessScan.partition_runs(rows)
      expect(runs).to be_empty
      expect(solo.map { it["position"] }).to eq([ 1, 3 ])
    end

    # The Carini into Sand case: Sand's own header was already correct, so it
    # carried no cut. It still has to join the run, because the crossfade that
    # smooths the step belongs half to its file.
    it "joins a track that has no cut of its own to its flagged neighbour" do
      rows = [ row(1, preceded: false, followed: true).merge("head_cut_s" => 0.02),
               row(2, preceded: true, followed: false) ]
      runs, = GaplessScan.partition_runs(rows)
      expect(runs.map { |r| r.map { it["position"] } }).to eq([ [ 1, 2 ] ])
    end
  end

  describe "gapless_scan:restore" do
    subject(:restore) { Rake::Task["gapless_scan:restore"].tap(&:reenable).invoke }

    let(:show) { create(:show, date: "2001-05-23") }
    let!(:track) { create(:track, show:, title: "Plasma", position: 1, set: "1") }
    let(:dir) { GaplessTrimService::BACKUP_DIR }
    let(:backup) { dir.join("2001-05-23_#{track.slug}_oldblobkey1234567890abcdef.mp3") }

    before do
      FileUtils.mkdir_p(dir)
      path = Rails.root.join("tmp/spec/restore_src.mp3")
      FileUtils.mkdir_p(path.dirname)
      unless path.exist?
        system("ffmpeg", "-y", "-v", "error", "-f", "lavfi",
               "-i", "sine=frequency=440:duration=1:sample_rate=44100",
               "-b:a", "192k", path.to_s, exception: true)
      end
      FileUtils.cp(path, backup)
      ENV["DATE"] = "2001-05-23"
      allow(WaveformImageService).to receive(:call)
      allow(Id3TagService).to receive(:call)
    end

    after do
      FileUtils.rm_f(backup)
      ENV.delete("DATE")
      ENV.delete("DRY_RUN")
    end

    it "puts the backup back on the track" do
      expect { restore }.to change { track.reload.mp3_audio.attached? }.to(true)
    end

    # The backup is the only copy of the original, and a track that has been
    # restored once may need restoring again.
    it "leaves the backup file in place" do
      restore
      expect(backup).to exist
    end

    it "changes nothing on a dry run" do
      ENV["DRY_RUN"] = "1"
      expect { restore }.not_to change { track.reload.mp3_audio.attached? }
    end
  end

  describe ".at_joint?" do
    it "keeps a clean track that sits between two others" do
      track = instance_double(Track, set: "1", position: 2)
      show = instance_double(Show, tracks: [
        instance_double(Track, set: "1", position: 1),
        track,
        instance_double(Track, set: "1", position: 3)
      ])
      allow(track).to receive(:show).and_return(show)
      expect(GaplessScan.at_joint?(track)).to be(true)
    end

    it "leaves a clean track alone when it is the only one in its set" do
      track = instance_double(Track, set: "E", position: 1)
      show = instance_double(Show, tracks: [ track ])
      allow(track).to receive(:show).and_return(show)
      expect(GaplessScan.at_joint?(track)).to be(false)
    end
  end
end
