require "rails_helper"

RSpec.describe Admin::StagingRender do
  let(:show) { create(:show, date: "2024-07-19") }
  let(:timeline) { Rails.root.join("tmp/spec/staging_timeline.flac") }
  let(:out) { Rails.root.join("tmp/spec/staging_render_out.mp3") }

  before do
    FileUtils.mkdir_p(timeline.dirname)
    unless File.exist?(timeline)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=30", "-c:a", "flac", timeline.to_s,
        exception: true
      )
    end
    FileUtils.rm_f(out)
  end

  def probe_duration(path)
    Admin::AudioProbe.duration_s(path)
  end

  def level_at(path, second)
    pcm = `ffmpeg -v error -ss #{second} -t 1 -i #{path} -f s16le -ac 1 -ar 8000 - 2>/dev/null`
    samples = pcm.unpack("s<*")
    samples.sum { |s| s.abs }.to_f / samples.size
  end

  describe ".ffmpeg_args" do
    it "seeks the input to the span and fades only when asked" do
      track = build(:staged_track, show:, start_s: 10, end_s: 25, fade_in_s: 2, fade_out_s: 3)
      args = described_class.ffmpeg_args(timeline: "/t.flac", track:)
      expect(args).to eq([
        "-ss", "10.000", "-to", "25.000", "-i", "/t.flac",
        "-af", "afade=t=in:st=0:d=2.00,afade=t=out:st=12.00:d=3.00"
      ])
    end

    it "omits the filter when both fades are zero" do
      track = build(:staged_track, show:, start_s: 0, end_s: 30)
      expect(described_class.ffmpeg_args(timeline: "/t.flac", track:))
        .to eq([ "-ss", "0.000", "-to", "30.000", "-i", "/t.flac" ])
    end
  end

  describe ".call" do
    it "renders exactly the span as mp3" do
      track = build(:staged_track, show:, start_s: 5, end_s: 20)
      described_class.call(timeline:, track:, out_path: out)
      expect(mp3_frame_sync?(File.binread(out))).to be(true)
      expect(probe_duration(out)).to be_within(0.1).of(15.0)
    end

    it "fades in linearly" do
      track = build(:staged_track, show:, start_s: 0, end_s: 10, fade_in_s: 2)
      described_class.call(timeline:, track:, out_path: out)
      full = level_at(out, 5)
      expect(level_at(out, 0.5) / full).to be_within(0.08).of(0.5)
      expect(level_at(out, 4) / full).to be_within(0.05).of(1.0)
    end

    it "fades out linearly to the end" do
      track = build(:staged_track, show:, start_s: 0, end_s: 10, fade_out_s: 4)
      described_class.call(timeline:, track:, out_path: out)
      full = level_at(out, 2)
      expect(level_at(out, 7.5) / full).to be_within(0.08).of(0.5)
    end

    it "raises when ffmpeg fails" do
      track = build(:staged_track, show:, start_s: 0, end_s: 10)
      expect { described_class.call(timeline: "/nope.flac", track:, out_path: out) }
        .to raise_error(Admin::StagingRender::Error, /ffmpeg failed/)
    end
  end
end
