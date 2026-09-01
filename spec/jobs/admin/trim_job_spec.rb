require "rails_helper"

RSpec.describe Admin::TrimJob do
  let(:show) { create(:show, date: "2024-07-19") }
  let(:song) { create(:song) }
  let(:track) { create(:track, show:, position: 1, songs: [ song ], slug: "trim-target") }
  let(:admin_job) { create(:admin_job, kind: "trim_preview", track:) }
  let(:source) { Rails.root.join("tmp/spec/audio_30s.mp3") }
  let(:opts) { { trim_start: 0.0, trim_end: 20.0, fade_in: 0.2, fade_out: 6.0 }.to_json }

  before do
    FileUtils.mkdir_p(source.dirname)
    unless File.exist?(source)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=30", "-b:a", "128k", source.to_s,
        exception: true
      )
    end
    track.mp3_audio.attach(
      io: File.open(source), filename: "audio.mp3", content_type: "audio/mpeg"
    )
    allow(WaveformImageService).to receive(:call)
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  describe "preview" do
    it "renders a preview without touching the attachment" do
      original_key = track.mp3_audio.blob.key
      described_class.new.perform(track.id, admin_job.id, opts, false)

      admin_job.reload
      expect(admin_job.status).to eq("done")
      path = admin_job.payload["audio_paths"].first
      expect(File.exist?(path)).to be(true)
      expect(track.reload.mp3_audio.blob.key).to eq(original_key)
    end

    it "does not change the track duration" do
      expect { described_class.new.perform(track.id, admin_job.id, opts, false) }
        .not_to change { track.reload.duration }
    end

    it "renders audio trimmed to the requested end" do
      described_class.new.perform(track.id, admin_job.id, opts, false)
      path = admin_job.reload.payload["audio_paths"].first
      expect(probe_duration(path)).to be_within(0.2).of(20.0)
    end

    it "keeps preview audio readable after the job completes" do
      described_class.new.perform(track.id, admin_job.id, opts, false)
      path = admin_job.reload.payload["audio_paths"].first

      GC.start
      expect(File.exist?(path)).to be(true)
      expect(File.size(path)).to be_positive
      expect(mp3_frame_sync?(File.binread(path))).to be(true)
      expect(probe_duration(path)).to be_within(0.2).of(20.0)
    end

    it "isolates each job's audio from a later render on the same track" do
      described_class.new.perform(track.id, admin_job.id, opts, false)
      first_path = admin_job.reload.payload["audio_paths"].first
      first_bytes = File.binread(first_path)

      second_job = create(:admin_job, kind: "trim_preview", track:)
      shorter = { trim_start: 0.0, trim_end: 10.0, fade_in: 0.2, fade_out: 6.0 }.to_json
      described_class.new.perform(track.id, second_job.id, shorter, false)
      second_path = second_job.reload.payload["audio_paths"].first

      expect(second_path).not_to eq(first_path)
      expect(File.binread(first_path)).to eq(first_bytes)
      expect(probe_duration(first_path)).to be_within(0.2).of(20.0)
      expect(probe_duration(second_path)).to be_within(0.2).of(10.0)
    end
  end

  describe "apply" do
    it "replaces the attachment on apply" do
      original_key = track.mp3_audio.blob.key
      described_class.new.perform(track.id, admin_job.id, opts, true)
      expect(track.reload.mp3_audio.blob.key).not_to eq(original_key)
    end

    it "shrinks the track duration" do
      described_class.new.perform(track.id, admin_job.id, opts, true)
      expect(track.reload.duration).to be_within(200).of(20_000)
    end

    it "stores streamable audio for the applied render" do
      described_class.new.perform(track.id, admin_job.id, opts, true)
      path = admin_job.reload.payload["audio_paths"].first
      expect(File.exist?(path)).to be(true)
      expect(probe_duration(path)).to be_within(0.2).of(20.0)
    end
  end

  it "fails the admin job on a meaningless cut" do
    tiny = { trim_start: 0.0, trim_end: 29.9, fade_in: 0.2, fade_out: 6.0 }.to_json
    expect { described_class.new.perform(track.id, admin_job.id, tiny, false) }
      .to raise_error(AudioEdgeTrimService::TrimTooSmallError)
    expect(admin_job.reload.status).to eq("failed")
  end

  it "fails the admin job when the track has no audio" do
    track.mp3_audio.detach
    track.update!(audio_status: "missing")
    expect { described_class.new.perform(track.id, admin_job.id, opts, false) }
      .to raise_error(AudioEdgeTrimService::MissingAudioError)
    expect(admin_job.reload.status).to eq("failed")
  end
end
