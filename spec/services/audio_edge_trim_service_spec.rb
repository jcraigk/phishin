require "rails_helper"

RSpec.describe AudioEdgeTrimService do
  subject(:result) { described_class.call(track, trim_end:, dry_run:) }

  let(:show) { create(:show, date: "1996-11-02") }
  let(:track) { create(:track, show:, title: "Sweet Adeline", position: 15) }
  let(:trim_end) { 20.0 }
  let(:source) { Rails.root.join("tmp/spec/audio_30s.mp3") }

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
      io: File.open(source),
      filename: "audio.mp3",
      content_type: "audio/mpeg"
    )
    allow(WaveformImageService).to receive(:call)
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  context "with dry_run: true" do
    let(:dry_run) { true }

    it "renders the trimmed file" do
      expect(File.exist?(result[:output_path])).to be(true)
    end

    it "trims audio to the requested end" do
      expect(probe_duration(result[:output_path])).to be_within(0.2).of(trim_end)
    end

    it "does not replace the audio blob" do
      original_key = track.mp3_audio.blob.key
      result
      expect(track.reload.mp3_audio.blob.key).to eq(original_key)
    end

    it "does not change the track duration" do
      expect { result }.not_to change { track.reload.duration }
    end
  end

  context "with dry_run: false" do
    let(:dry_run) { false }

    it "replaces the audio blob" do
      original_key = track.mp3_audio.blob.key
      result
      expect(track.reload.mp3_audio.blob.key).not_to eq(original_key)
    end

    it "updates the track duration" do
      result
      expect(track.reload.duration).to be_within(200).of(trim_end * 1000)
    end

    it "writes a backup of the original audio" do
      expect(File.size(result[:backup_path])).to eq(File.size(source))
    end

    it "regenerates the waveform image" do
      result
      expect(WaveformImageService).to have_received(:call).with(track)
    end
  end

  context "when the cut is below the minimum" do
    let(:dry_run) { true }
    let(:trim_end) { 28.0 }

    it "raises TrimTooSmallError" do
      expect { result }.to raise_error(described_class::TrimTooSmallError)
    end
  end

  context "with a custom min_cut" do
    subject(:result) { described_class.call(track, trim_end:, min_cut: 1.5, dry_run: true) }

    let(:trim_end) { 28.0 }

    it "allows cuts above the custom minimum" do
      expect(File.exist?(result[:output_path])).to be(true)
    end
  end

  context "with a leading trim" do
    subject(:result) do
      described_class.call(
        track, trim_start: 6.0, trim_end: 30.0, fade_in: 0.2, fade_out: 0.0, dry_run: true
      )
    end

    it "trims audio from the requested start" do
      expect(probe_duration(result[:output_path])).to be_within(0.2).of(24.0)
    end
  end

  context "when the track has no audio" do
    let(:dry_run) { true }

    it "raises MissingAudioError" do
      track.mp3_audio.detach
      track.update!(audio_status: "missing")
      expect { result }.to raise_error(described_class::MissingAudioError)
    end
  end
end
