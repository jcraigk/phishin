require "rails_helper"

RSpec.describe GaplessTrimService do
  subject(:result) { described_class.call(track, head_cut:, tail_cut:, dry_run:) }

  let(:show) { create(:show, date: "2022-07-15") }
  let(:track) { create(:track, show:, title: "Ghost", position: 3, set: "1") }
  let(:head_cut) { 0.0 }
  let(:tail_cut) { 0.0 }
  let(:dry_run) { true }
  let(:source) { Rails.root.join("tmp/spec/gapless_source.mp3") }

  before do
    FileUtils.mkdir_p(source.dirname)
    unless File.exist?(source)
      # A tone with silence bolted on at both ends, the shape an mp3 exported
      # without a LAME header decodes to.
      system(
        "ffmpeg", "-y", "-v", "error",
        "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo:d=0.03",
        "-f", "lavfi", "-i", "sine=frequency=440:duration=10:sample_rate=44100",
        "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo:d=0.04",
        "-filter_complex", "[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]",
        "-map", "[out]", "-b:a", "192k", source.to_s, exception: true
      )
    end
    track.mp3_audio.attach(
      io: File.open(source), filename: "a.mp3", content_type: "audio/mpeg"
    )
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  # What a decoder actually yields, which ffprobe's container duration overstates
  # by the decoder delay it does not subtract.
  def decoded_duration(path)
    rate, channels = `ffprobe -v error -select_streams a:0 \
      -show_entries stream=sample_rate,channels -of csv=p=0 #{path}`.strip.split(",")
    bytes = `ffmpeg -v error -i #{path} -f s16le -acodec pcm_s16le - | wc -c`.to_i
    bytes / (2 * channels.to_i) / rate.to_f
  end

  describe "validation" do
    it "refuses a no-op" do
      expect { result }.to raise_error(described_class::NothingToTrimError)
    end

    context "when the cut is longer than the track" do
      let(:tail_cut) { 999.0 }

      it "refuses" do
        expect { result }.to raise_error(described_class::TrimTooLargeError)
      end
    end

    context "when the head cut exceeds what is safe" do
      let(:head_cut) { described_class::MAX_HEAD_CUT_S + 0.01 }

      it "refuses" do
        expect { result }.to raise_error(described_class::TrimTooLargeError)
      end
    end

    # A tail cut is a run of exact zeros, so it is allowed to be far longer than
    # a head cut: some tracks end with most of a second of digital black.
    context "when the tail cut is long but still silence" do
      let(:tail_cut) { 0.5 }

      it "allows it" do
        expect { result }.not_to raise_error
      end
    end
  end

  # ffprobe reports the container duration, which runs a decoder delay longer
  # than what comes out of the decoder - about 4ms for an mp3. Measuring the cut
  # against it left that much of the padding behind on every track, which is
  # audible as a gap at a joint, so the cut has to be taken from the decoded
  # length instead.
  describe "the length it cuts against" do
    let(:tail_cut) { 0.04 }

    it "cuts from the decoded length rather than the container's" do
      expect(decoded_duration(result[:output_path]))
        .to be_within(0.001).of(decoded_duration(source) - 0.04)
    end

    it "reports the decoded length as the original" do
      expect(result[:original_duration_s])
        .to be_within(0.001).of(decoded_duration(source))
    end

    # The catalog's own files are where the two disagree: ffprobe reads about
    # 4ms more than the decoder yields. The fixture is encoded cleanly and does
    # not diverge, so this pins the container duration out of the calculation
    # rather than relying on the fixture to expose it.
    it "does not read the length from the container" do
      service = described_class.new(track, tail_cut:, dry_run: true)
      allow(service).to receive(:probe).and_call_original
      service.call
      expect(service).not_to have_received(:probe).with("duration")
    end
  end

  # The backups are the only copy of the untrimmed audio, so the cap has to stop
  # the trim rather than let it proceed with nothing to roll back to.
  describe "the backup budget" do
    let(:tail_cut) { 0.04 }
    let(:dry_run) { false }

    it "refuses to trim once the backups fill their budget" do
      allow(described_class).to receive(:backup_bytes_used).and_return(
        described_class::BACKUP_BUDGET_BYTES
      )
      expect { result }.to raise_error(described_class::BackupBudgetError)
    end

    it "leaves the audio alone when it refuses" do
      allow(described_class).to receive(:backup_bytes_used).and_return(
        described_class::BACKUP_BUDGET_BYTES
      )
      before_key = track.mp3_audio.blob.key
      suppress(described_class::BackupBudgetError) { result }
      expect(track.reload.mp3_audio.blob.key).to eq(before_key)
    end

    it "trims while there is room" do
      allow(described_class).to receive(:backup_bytes_used).and_return(0)
      expect(result[:applied]).to be true
    end

    it "writes the backup under the backup directory" do
      allow(described_class).to receive(:backup_bytes_used).and_return(0)
      expect(result[:backup_path]).to start_with(described_class::BACKUP_DIR.to_s)
    end
  end

  describe "a dry run" do
    let(:tail_cut) { 0.04 }

    it "renders a shorter file" do
      expect(probe_duration(result[:output_path]))
        .to be_within(0.02).of(result[:original_duration_s] - 0.04)
    end

    it "leaves the attachment alone" do
      before_key = track.mp3_audio.blob.key
      result
      expect(track.reload.mp3_audio.blob.key).to eq(before_key)
    end

    it "reports what it would cut" do
      expect(result).to include(head_cut_s: 0.0, tail_cut_s: 0.04, applied: false)
    end
  end

  describe "applying the trim" do
    let(:dry_run) { false }
    let(:tail_cut) { 0.04 }

    it "replaces the audio" do
      before_key = track.mp3_audio.blob.key
      result
      expect(track.reload.mp3_audio.blob.key).not_to eq(before_key)
    end

    it "backs the original up" do
      expect(File.exist?(result[:backup_path])).to be true
    end

    it "keeps the backup playable" do
      expect(probe_duration(result[:backup_path]))
        .to be_within(0.02).of(result[:original_duration_s])
    end

    it "reprocesses the track" do
      result
      expect(Id3TagService).to have_received(:call).with(track)
    end
  end

  describe "what the trim removes" do
    let(:dry_run) { false }
    let(:head_cut) { 0.03 }
    let(:tail_cut) { 0.04 }

    def edge_silence(path)
      pcm = `ffmpeg -v error -i #{path} -f s16le -ac 2 -ar 44100 -`
      amps = pcm.unpack("s<*").each_slice(2).map { it.map(&:abs).max }
      head = amps.take_while { it < 50 }.size
      tail = amps.reverse.take_while { it < 50 }.size
      [ head / 44_100.0, tail / 44_100.0 ]
    end

    it "removes the silence at both edges" do
      head, tail = edge_silence(result[:output_path])
      expect([ head, tail ].max).to be < 0.005
    end

    # Without this the encoder's own delay and padding go undeclared and the
    # trim puts back what it removed.
    it "declares its padding in a LAME header" do
      data = File.binread(result[:output_path])
      id3 = data.start_with?("ID3") ? 10 + data.byteslice(6, 4).bytes.each_with_index
        .sum { |b, i| (b & 0x7f) << (7 * (3 - i)) } : 0
      expect(data.byteslice(id3, 2048)).to include("LAME")
    end

    it "keeps the audio between them" do
      expect(probe_duration(result[:output_path])).to be_within(0.05).of(10.0)
    end
  end
end
