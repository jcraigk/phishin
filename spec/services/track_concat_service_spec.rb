require "rails_helper"

RSpec.describe TrackConcatService do
  subject(:result) { described_class.call(tracks:, dry_run:) }

  let(:show) { create(:show, date: "1989-05-26") }
  let(:track1) { create(:track, show:, title: "First", position: 1) }
  let(:track2) { create(:track, show:, title: "Second", position: 2) }
  let(:tracks) { [ track1, track2 ] }
  let(:dry_run) { true }

  def tone(seconds:, frequency:, bitrate: "128k")
    path = Rails.root.join("tmp/spec/tone_#{frequency}_#{seconds}_#{bitrate}.mp3")
    FileUtils.mkdir_p(path.dirname)
    unless File.exist?(path)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=#{frequency}:duration=#{seconds}", "-b:a", bitrate,
        path.to_s, exception: true
      )
    end
    path
  end

  def attach(track, path)
    track.mp3_audio.attach(
      io: File.open(path), filename: "audio.mp3", content_type: "audio/mpeg"
    )
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  before do
    attach(track1, tone(seconds: 10, frequency: 440))
    attach(track2, tone(seconds: 6, frequency: 880))
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  describe "joining two tracks" do
    it "renders a file whose duration is the sum of the sources" do
      expect(probe_duration(result[:output_path])).to be_within(0.3).of(16.0)
    end

    it "reports the joined duration" do
      expect(result[:duration_s]).to be_within(0.3).of(16.0)
    end

    it "reports each source duration in order" do
      expect(result[:source_durations].first).to be_within(0.3).of(10.0)
    end

    it "reports the second source duration" do
      expect(result[:source_durations].last).to be_within(0.3).of(6.0)
    end

    it "reports the track ids in order" do
      expect(result[:track_ids]).to eq([ track1.id, track2.id ])
    end
  end

  describe "joining three tracks" do
    let(:track3) { create(:track, show:, title: "Third", position: 3) }
    let(:tracks) { [ track1, track2, track3 ] }

    before { attach(track3, tone(seconds: 4, frequency: 220)) }

    it "renders a file whose duration is the sum of all three sources" do
      expect(probe_duration(result[:output_path])).to be_within(0.4).of(20.0)
    end

    it "reports all three source durations" do
      expect(result[:source_durations].size).to eq(3)
    end
  end

  describe "codec and bitrate handling" do
    it "copies the streams when the sources share a bitrate" do
      expect(result[:reencoded]).to be(false)
    end

    it "reports no re-encode bitrate on the copy path" do
      expect(result[:bitrate]).to be_nil
    end

    context "when the sources have different bitrates" do
      before { attach(track2, tone(seconds: 6, frequency: 880, bitrate: "192k")) }

      it "re-encodes" do
        expect(result[:reencoded]).to be(true)
      end

      # ffprobe reports the container's measured rate, so a nominal 192k file
      # probes a few kbps high; what matters is that the higher source wins.
      it "re-encodes at the highest source bitrate" do
        expect(result[:bitrate].to_i).to be_within(6).of(192)
      end

      it "still preserves the summed duration" do
        expect(probe_duration(result[:output_path])).to be_within(0.3).of(16.0)
      end
    end
  end

  describe "validation" do
    context "with fewer than two tracks" do
      let(:tracks) { [ track1 ] }

      it "raises" do
        expect { result }.to raise_error(described_class::TooFewTracksError)
      end
    end

    context "when a track has no audio" do
      before { track2.mp3_audio.purge }

      it "raises" do
        expect { result }.to raise_error(described_class::MissingAudioError, /Second/)
      end
    end

    context "when the tracks are from different shows" do
      let(:other_show) { create(:show, date: "1991-07-19") }
      let(:track2) { create(:track, show: other_show, title: "Second", position: 1) }

      it "raises" do
        expect { result }.to raise_error(described_class::ShowMismatchError)
      end
    end
  end

  describe "dry run" do
    it "reports that nothing was applied" do
      expect(result[:applied]).to be(false)
    end

    it "leaves the first track's blob untouched" do
      expect { result }.not_to change { track1.reload.mp3_audio.blob.key }
    end

    it "leaves the second track's blob untouched" do
      expect { result }.not_to change { track2.reload.mp3_audio.blob.key }
    end

    it "leaves the first track's duration untouched" do
      expect { result }.not_to change { track1.reload.duration }
    end

    it "leaves the second track's duration untouched" do
      expect { result }.not_to change { track2.reload.duration }
    end

    it "destroys no tracks" do
      expect { result }.not_to change(Track, :count)
    end
  end

  describe "without dry run" do
    let(:dry_run) { false }

    it "reports that the render was applied" do
      expect(result[:applied]).to be(true)
    end

    it "renders into the durable output directory" do
      expect(result[:output_path]).to start_with(described_class::OUTPUT_DIR.to_s)
    end

    it "still changes no attachments, since this service only renders" do
      expect { result }.not_to change { track2.reload.mp3_audio.blob.key }
    end

    it "still renders the summed duration" do
      expect(probe_duration(result[:output_path])).to be_within(0.3).of(16.0)
    end
  end
end
