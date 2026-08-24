require "rails_helper"

RSpec.describe GaplessJointService do
  subject(:result) { described_class.call(tracks, cuts:, dry_run:) }

  let(:show) { create(:show, date: "2001-05-23") }
  let(:first) { create(:track, show:, title: "Blaze On", position: 1, set: "1") }
  let(:second) { create(:track, show:, title: "Plasma", position: 2, set: "1") }
  let(:third) { create(:track, show:, title: "Carini", position: 3, set: "1") }
  let(:tracks) { [ first, second ] }
  let(:cuts) do
    { first.id => { head: 0.02, tail: 0.02 }, second.id => { head: 0.02, tail: 0.02 } }
  end
  let(:dry_run) { false }

  # Each part is a different tone so the joints are identifiable in the output,
  # and each carries padding at the edges the cuts remove - the shape of a file
  # written without a gapless header.
  def build_part(path, freq, seconds)
    return path if File.exist?(path)
    FileUtils.mkdir_p(path.dirname)
    system(
      "ffmpeg", "-y", "-v", "error",
      "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo:d=0.02",
      "-f", "lavfi", "-i",
      "sine=frequency=#{freq}:duration=#{seconds}:sample_rate=44100",
      "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo:d=0.02",
      "-filter_complex",
      "[1:a]aformat=channel_layouts=stereo[m];" \
      "[0:a][m][2:a]concat=n=3:v=0:a=1[out]",
      "-map", "[out]", "-b:a", "192k", path.to_s, exception: true
    )
    path
  end

  def attach(track, freq, seconds)
    path = build_part(Rails.root.join("tmp/spec/joint_#{freq}.mp3"), freq, seconds)
    track.mp3_audio.attach(
      io: File.open(path), filename: "#{freq}.mp3", content_type: "audio/mpeg"
    )
  end

  def decoded_duration(path)
    rate, channels = `ffprobe -v error -select_streams a:0 \
      -show_entries stream=sample_rate,channels -of csv=p=0 #{path}`.strip.split(",")
    bytes = `ffmpeg -v error -i #{path} -f s16le -acodec pcm_s16le - | wc -c`.to_i
    bytes / (2 * channels.to_i) / rate.to_f
  end

  def mono_samples(path)
    `ffmpeg -v error -i #{path} -f s16le -acodec pcm_s16le -ac 1 -`.unpack("s<*")
  end

  # The fault this service exists to remove is a run of near-silence where two
  # files meet - the padding one of them still carries. A lone quiet sample is
  # just the waveform crossing zero, so what matters is the longest run of them,
  # measured across the seam as a listener hears it: each file decoded on its
  # own, then played back to back.
  def quiet_run_at_joint(left, right, window: 30)
    seam = mono_samples(left).last(window) + mono_samples(right).first(window)
    seam.slice_when { |a, b| (a.abs < 40) != (b.abs < 40) }
        .select { it.first.abs < 40 }
        .map(&:size).max.to_i
  end

  before do
    attach(first, 440, 4)
    attach(second, 660, 4)
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  describe "validation" do
    it "refuses tracks that are not adjacent" do
      expect { described_class.call([ first, third ], cuts:) }
        .to raise_error(described_class::NotAdjacentError)
    end

    it "refuses a run of one" do
      expect { described_class.call([ first ], cuts:) }
        .to raise_error(described_class::NotAdjacentError)
    end

    it "refuses a track with no audio" do
      second.mp3_audio.purge
      expect { result }.to raise_error(described_class::MissingAudioError)
    end
  end

  describe "a dry run" do
    let(:dry_run) { true }

    it "leaves the attachments alone" do
      keys = tracks.map { it.mp3_audio.blob.key }
      result
      expect(tracks.map { it.reload.mp3_audio.blob.key }).to eq(keys)
    end

    it "renders one file per track" do
      expect(result[:outputs].size).to eq(2)
    end
  end

  describe "the rendered pair" do
    it "writes new audio for every track in the run" do
      keys = tracks.map { it.mp3_audio.blob.key }
      result
      expect(tracks.map { it.reload.mp3_audio.blob.key }).not_to eq(keys)
    end

    # The whole point: the two files still join seamlessly for someone who
    # downloads them and concatenates them.
    it "joins without a dropout when the files are decoded separately" do
      outputs = result[:outputs]
      expect(quiet_run_at_joint(outputs.first[:path], outputs.last[:path])).to be < 3
    end

    # The overlap is shared between the two files rather than added to either,
    # so the pair is exactly one fade shorter than the sum of the trimmed parts.
    it "spends the overlap once across the pair" do
      outputs = result[:outputs]
      total = outputs.sum { decoded_duration(it[:path]) }
      # Each fixture decodes to 4.04s and gives up its 0.04s of padding, so the
      # pair holds 8s of audio less the single overlap they share. The tolerance
      # covers lame rounding each file up to a whole frame.
      expect(total).to be_within(0.01).of(8.0 - described_class::FADE_S)
    end

    it "gives every output a gapless header" do
      headers = result[:outputs].map do |out|
        `ffprobe -v error -show_entries format=tags -of csv=p=0 #{out[:path]}`
        File.binread(out[:path], 200_000).include?("LAME")
      end
      expect(headers).to all(be true)
    end

    it "backs up every original" do
      expect(result[:backup_paths].size).to eq(2)
    end
  end

  describe "the fade at each joint" do
    # The tick this widening exists for: trimming the second track's padding
    # uncovers a hard edge, and the short fade cannot span it. Two tones that
    # meet far apart in level stand in for that here.
    it "widens the fade when the trimmed edges meet at an audible step" do
      service = described_class.new(tracks, cuts:, dry_run: true)
      loud = { file: instance_double(Tempfile, path: "l"), start: 0.0, finish: 1.0, kept: 1.0 }
      quiet = { file: instance_double(Tempfile, path: "q"), start: 0.0, finish: 1.0, kept: 1.0 }
      allow(service).to receive(:edge_samples).with(loud, tail: true)
                                              .and_return([ 100 ] * 4_450)
      allow(service).to receive(:edge_samples).with(quiet, tail: false)
                                              .and_return([ 3_000 ] * 4_450)
      expect(service.send(:audible_step?, loud, quiet)).to be(true)
    end

    it "leaves the fade alone when the step is small against the music" do
      service = described_class.new(tracks, cuts:, dry_run: true)
      left = { file: instance_double(Tempfile, path: "l"), start: 0.0, finish: 1.0, kept: 1.0 }
      right = { file: instance_double(Tempfile, path: "r"), start: 0.0, finish: 1.0, kept: 1.0 }
      # One continuous tone split across the seam, which is what a joint inside
      # an unbroken performance looks like: loud, and with no step where the
      # two files meet.
      tone = Array.new(8_900) { (8_000 * Math.sin(it * 0.05)).round }
      allow(service).to receive(:edge_samples).with(left, tail: true)
                                              .and_return(tone.first(4_450))
      allow(service).to receive(:edge_samples).with(right, tail: false)
                                              .and_return(tone.last(4_450))
      expect(service.send(:audible_step?, left, right)).to be(false)
    end

    # A quiet passage reads a high ratio off a step too small to hear.
    it "leaves the fade alone when the step is tiny however quiet the passage" do
      service = described_class.new(tracks, cuts:, dry_run: true)
      left = { file: instance_double(Tempfile, path: "l"), start: 0.0, finish: 1.0, kept: 1.0 }
      right = { file: instance_double(Tempfile, path: "r"), start: 0.0, finish: 1.0, kept: 1.0 }
      allow(service).to receive(:edge_samples).with(left, tail: true).and_return([ 0 ] * 4_450)
      allow(service).to receive(:edge_samples).with(right, tail: false).and_return([ 40 ] * 4_450)
      expect(service.send(:audible_step?, left, right)).to be(false)
    end
  end

  describe "a longer run" do
    let(:tracks) { [ first, second, third ] }
    let(:cuts) do
      {
        first.id => { head: 0.02, tail: 0.02 },
        second.id => { head: 0.02, tail: 0.02 },
        third.id => { head: 0.02, tail: 0.02 }
      }
    end

    before { attach(third, 880, 4) }

    it "renders every part in one pass" do
      expect(result[:outputs].size).to eq(3)
    end

    # A middle track is faded at both ends, which is why a run cannot be
    # processed as a sequence of independent pairs.
    it "joins cleanly at both of its joints" do
      outputs = result[:outputs]
      runs = [ [ 0, 1 ], [ 1, 2 ] ].map do |left, right|
        quiet_run_at_joint(outputs[left][:path], outputs[right][:path])
      end
      expect(runs).to all(be < 3)
    end
  end
end
