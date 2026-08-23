require "rails_helper"

RSpec.describe TrackMergeService do
  subject(:result) { described_class.call(first, second:, title:, dry_run:) }

  let(:show) { create(:show, date: "1990-10-12") }
  let(:hyhu) { create(:song, title: "Hold Your Head Up") }
  let(:terrapin) { create(:song, title: "Terrapin") }
  let(:first) do
    create(:track, show:, title: "Hold Your Head Up", songs: [ hyhu ],
                   position: 13, set: "2")
  end
  let(:second) do
    create(:track, show:, title: "Terrapin > Hold Your Head Up",
                   songs: [ terrapin, hyhu ], position: 14, set: "2")
  end
  let(:title) { "HYHU > Terrapin > HYHU" }
  let(:dry_run) { true }
  let(:source_a) { Rails.root.join("tmp/spec/merge_a.mp3") }
  let(:source_b) { Rails.root.join("tmp/spec/merge_b.mp3") }

  before do
    FileUtils.mkdir_p(source_a.dirname)
    # Keyed on fixed paths, not on source_a: a context that overrides source_a
    # would otherwise have its own fixture overwritten with a plain tone here,
    # depending on which example ran first.
    {
      Rails.root.join("tmp/spec/merge_a.mp3") => [ 440, 10 ],
      source_b => [ 660, 20 ]
    }.each do |path, (freq, secs)|
      next if File.exist?(path)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=#{freq}:duration=#{secs}", "-b:a", "128k", path.to_s,
        exception: true
      )
    end
    first.mp3_audio.attach(
      io: File.open(source_a), filename: "a.mp3", content_type: "audio/mpeg"
    )
    second.mp3_audio.attach(
      io: File.open(source_b), filename: "b.mp3", content_type: "audio/mpeg"
    )
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  # A quiet tone ending in full-scale noise, the shape the affected files have.
  # The burst is brief enough that the music behind it stays quiet, since
  # detection compares the two.
  def build_burst_fixture(path)
    FileUtils.mkdir_p(path.dirname)
    system(
      "ffmpeg", "-y", "-v", "error",
      "-f", "lavfi", "-i", "sine=frequency=440:duration=9.995:sample_rate=44100",
      "-f", "lavfi", "-i", "anoisesrc=duration=0.005:amplitude=1:sample_rate=44100",
      "-filter_complex", "[0:a]volume=0.05[a];[a][1:a]concat=n=2:v=0:a=1[out]",
      "-map", "[out]", "-b:a", "320k", path.to_s, exception: true
    )
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  # Some files carry encoder padding at the head with no gapless header to
  # declare it, so the padding decodes as ordinary near-silence and lands in the
  # middle of a merge as a dropout. Unlike a head burst this is quiet, so the
  # burst rules never fire on it.
  describe "the silent head trim" do
    # A tone preceded by a stretch of near-silence, the shape a file without a
    # gapless header decodes to.
    def build_silent_head_fixture(path, silence_s)
      FileUtils.mkdir_p(path.dirname)
      system(
        "ffmpeg", "-y", "-v", "error",
        "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo:d=#{silence_s}",
        "-f", "lavfi", "-i", "sine=frequency=660:duration=20:sample_rate=44100",
        "-filter_complex", "[0:a][1:a]concat=n=2:v=0:a=1[out]",
        "-map", "[out]", "-b:a", "192k", path.to_s, exception: true
      )
    end

    it "leaves a track that starts on audio untouched" do
      expect(result[:head_silence_trimmed]).to be(false)
    end

    context "when the second track starts with silent padding" do
      let(:source_b) do
        path = Rails.root.join("tmp/spec/merge_silent_head.mp3")
        build_silent_head_fixture(path, 0.025)
        path
      end

      it "detects the silent head" do
        expect(result[:head_silence_trimmed]).to be(true)
      end

      it "leaves no dropout at the joint" do
        pcm = `ffmpeg -v error -i #{result[:output_path]} -f s16le -ac 2 -ar 44100 -`
        amps = pcm.unpack("s<*").each_slice(2).map { it.map(&:abs).max }
        joint = (10.0 * 44_100).to_i
        window = amps[(joint - 441)..(joint + 441)] || []
        expect(window.count { it < 20 }).to be < 44
      end
    end
  end

  describe "the encoder flush trim" do
    it "leaves a clean track untouched" do
      expect(result[:tail_trimmed]).to be(false)
    end

    it "keeps the full duration when nothing is trimmed" do
      expect(probe_duration(result[:output_path])).to be_within(0.6).of(30.0)
    end

    context "when the first track ends in a full-scale burst" do
      # Built in the let, not a before block: the outer before block attaches
      # source_a, and RSpec runs outer before blocks first, so the file has to
      # exist by the time the path is first asked for.
      let(:source_a) do
        path = Rails.root.join("tmp/spec/merge_burst_source.mp3")
        build_burst_fixture(path)
        path
      end

      it "detects the burst" do
        expect(result[:tail_trimmed]).to be(true)
      end

      it "shortens the first part by the trim" do
        expect(probe_duration(result[:output_path])).to be_within(0.6).of(30.0)
      end
    end
  end

  describe "dry run" do
    it "renders the two tracks into one file" do
      expect(probe_duration(result[:output_path])).to be_within(0.6).of(30.0)
    end

    it "changes nothing in the database" do
      expect { result }.not_to change { show.tracks.reload.count }
    end

    it "leaves the original titles alone" do
      result
      expect(first.reload.title).to eq("Hold Your Head Up")
      expect(second.reload.title).to eq("Terrapin > Hold Your Head Up")
    end

    it "reports both source durations" do
      expect(result[:first_duration_s]).to be_within(0.6).of(10.0)
      expect(result[:second_duration_s]).to be_within(0.6).of(20.0)
    end
  end

  describe "applying the merge" do
    let(:dry_run) { false }

    it "keeps the first track and removes the second" do
      result
      expect(Track.exists?(first.id)).to be true
      expect(Track.exists?(second.id)).to be false
    end

    it "retitles the surviving track" do
      result
      expect(first.reload.title).to eq(title)
    end

    it "regenerates the slug from the new title" do
      result
      expect(first.reload.slug).to eq("hyhu-terrapin-hyhu")
    end

    it "keeps the first track's position" do
      expect { result }.not_to change { first.reload.position }
    end

    it "associates the union of both tracks' songs" do
      result
      expect(first.reload.songs).to contain_exactly(hyhu, terrapin)
    end

    it "attaches the concatenated audio" do
      result
      expect(first.reload.mp3_audio).to be_attached
    end

    it "closes the position gap left by the removed track" do
      create(:track, show:, title: "Poor Heart", songs: [ terrapin ],
                     position: 15, set: "2")
      result
      expect(show.tracks.reload.order(:position).map(&:position)).to eq([ 13, 14 ])
    end

    it "backs up both source files" do
      expect(result[:backup_paths].size).to eq(2)
      expect(result[:backup_paths]).to all(satisfy { File.exist?(it) })
    end
  end

  describe "likes" do
    let(:dry_run) { false }
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    it "keeps a like already on the first track" do
      create(:like, likable: first, user:)
      result
      expect(first.reload.likes.count).to eq(1)
    end

    it "moves a like from the second track" do
      create(:like, likable: second, user:)
      result
      expect(first.reload.likes.map(&:user)).to eq([ user ])
    end

    it "does not duplicate a user who liked both" do
      create(:like, likable: first, user:)
      create(:like, likable: second, user:)
      result
      expect(first.reload.likes.count).to eq(1)
    end

    it "merges likes from different users" do
      create(:like, likable: first, user:)
      create(:like, likable: second, user: other_user)
      result
      expect(first.reload.likes.map(&:user)).to contain_exactly(user, other_user)
    end
  end

  describe "track tags" do
    let(:dry_run) { false }
    let(:tag) { create(:tag, name: "SBD") }
    let(:other_tag) { create(:tag, name: "Jamcharts") }

    it "keeps an untimestamped tag from the first track" do
      create(:track_tag, track: first, tag:)
      result
      expect(first.reload.tags).to eq([ tag ])
    end

    it "moves a tag from the second track" do
      create(:track_tag, track: second, tag: other_tag)
      result
      expect(first.reload.tags).to eq([ other_tag ])
    end

    it "does not duplicate the same untimestamped tag on both" do
      create(:track_tag, track: first, tag:)
      create(:track_tag, track: second, tag:)
      result
      expect(first.reload.track_tags.count).to eq(1)
    end

    it "rebases a timestamped tag from the second track onto the merged clock" do
      create(:track_tag, track: second, tag: other_tag,
                         starts_at_second: 5, ends_at_second: 9)
      result
      moved = first.reload.track_tags.find { it.tag == other_tag }
      expect(moved.starts_at_second).to be_within(1).of(15)
      expect(moved.ends_at_second).to be_within(1).of(19)
    end

    it "leaves a timestamped tag on the first track where it is" do
      create(:track_tag, track: first, tag:, starts_at_second: 3, ends_at_second: 6)
      result
      kept = first.reload.track_tags.find { it.tag == tag }
      expect(kept.starts_at_second).to eq(3)
    end
  end

  describe "jam start" do
    let(:dry_run) { false }

    it "keeps the first track's jam start" do
      first.update!(jam_starts_at_second: 4)
      result
      expect(first.reload.jam_starts_at_second).to eq(4)
    end

    it "rebases the second track's jam start when the first has none" do
      second.update!(jam_starts_at_second: 5)
      result
      expect(first.reload.jam_starts_at_second).to be_within(1).of(15)
    end
  end

  describe "playlist entries" do
    let(:dry_run) { false }
    # The factory seeds two entries of its own; they are repurposed rather than
    # added to, so positions stay unique.
    let(:playlist) { create(:playlist) }
    let(:entries) { playlist.playlist_tracks.order(:position) }

    def entry_for_second(**attrs)
      entries.first.update!(track: second, **attrs)
      entries.last.destroy!
    end

    it "repoints an entry for the second track at the merged track" do
      entry_for_second
      result
      expect(playlist.playlist_tracks.reload.map(&:track)).to eq([ first ])
    end

    it "rebases a second-track excerpt onto the merged clock" do
      entry_for_second(starts_at_second: 5, ends_at_second: 9)
      result
      entry = playlist.playlist_tracks.reload.first
      expect(entry.starts_at_second).to be_within(1).of(15)
      expect(entry.ends_at_second).to be_within(1).of(19)
    end

    it "collapses consecutive entries for both halves into one" do
      entries.first.update!(track: first)
      entries.last.update!(track: second)
      result
      expect(playlist.playlist_tracks.reload.count).to eq(1)
    end

    it "keeps the surviving entry pointing at the merged track" do
      entries.first.update!(track: first)
      entries.last.update!(track: second)
      result
      expect(playlist.playlist_tracks.reload.map(&:track)).to eq([ first ])
    end
  end

  describe "validation" do
    let(:dry_run) { true }

    context "when the tracks are not adjacent" do
      before { second.update!(position: 20) }

      it "refuses to merge" do
        expect { result }.to raise_error(described_class::NotAdjacentError)
      end
    end

    context "when the tracks are in different sets" do
      before { second.update!(set: "1") }

      it "refuses to merge" do
        expect { result }.to raise_error(described_class::NotAdjacentError)
      end
    end

    context "when the tracks belong to different shows" do
      before { second.update!(show: create(:show, date: "1991-01-01")) }

      it "refuses to merge" do
        expect { result }.to raise_error(described_class::NotAdjacentError)
      end
    end

    context "when a track has no audio" do
      before { second.mp3_audio.purge }

      it "refuses to merge" do
        expect { result }.to raise_error(described_class::MissingAudioError)
      end
    end

    context "when the title is blank" do
      let(:title) { "  " }

      it "refuses to merge" do
        expect { result }.to raise_error(described_class::TitleError)
      end
    end
  end

  # A three-track sandwich used to be two calls, which rendered an intermediate
  # mp3, tagged it (Id3TagService rewrites through Mp3Info, which does not carry
  # the Xing gapless header and appends ~45ms of decoder padding), and then fed
  # that padded file into the second merge. The padding landed between the two
  # joints as an audible dropout. One pass, one encode, no intermediate.
  describe "a three-track sandwich" do
    subject(:result) do
      described_class.call(first, second:, third:, title:, dry_run:)
    end

    let(:source_c) { Rails.root.join("tmp/spec/merge_c.mp3") }
    let(:third) do
      create(:track, show:, title: "Hold Your Head Up", songs: [ hyhu ],
                     position: 15, set: "2")
    end

    before do
      unless File.exist?(source_c)
        system(
          "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
          "sine=frequency=880:duration=5", "-b:a", "128k", source_c.to_s,
          exception: true
        )
      end
      third.mp3_audio.attach(
        io: File.open(source_c), filename: "c.mp3", content_type: "audio/mpeg"
      )
    end

    def interior_silence_ms(path)
      pcm = `ffmpeg -v error -i #{path} -f s16le -ac 2 -ar 44100 -`
      samples = pcm.unpack("s<*").each_slice(2).map { it.map(&:abs).max }
      # Ignore the encoder padding every mp3 carries at each end.
      edge = 4_410
      runs = []
      run = 0
      samples.each_with_index do |amp, i|
        if amp < 20
          run += 1
        else
          runs << [ i - run, run ] if run.positive?
          run = 0
        end
      end
      runs.select { |start, len| start > edge && start + len < samples.size - edge }
          .map { |_start, len| len / 44.1 }
    end

    it "renders all three parts into one file" do
      expect(probe_duration(result[:output_path])).to be_within(0.6).of(35.0)
    end

    it "leaves no dropout at the joints" do
      expect(interior_silence_ms(result[:output_path]).max.to_f).to be < 1.0
    end

    it "reports the third source duration" do
      expect(result[:third_duration_s]).to be_within(0.6).of(5.0)
    end

    context "when applied" do
      let(:dry_run) { false }

      it "keeps the first track and removes the other two" do
        result
        expect(Track.exists?(first.id)).to be true
        expect(Track.exists?(second.id)).to be false
        expect(Track.exists?(third.id)).to be false
      end

      it "closes the position gap left by both removals" do
        create(:track, show:, title: "Weekapaug Groove", position: 16, set: "2")
        result
        expect(show.tracks.reload.find_by(title: "Weekapaug Groove").position)
          .to eq(14)
      end
    end
  end

  describe "slug renumbering" do
    let(:dry_run) { false }

    it "renumbers same-titled siblings in position order" do
      create(:track, show:, title:, songs: [ hyhu ], position: 20, set: "2")
      result
      slugs = show.tracks.reload.order(:position)
                  .select { it.title == title }.map { it.slug }
      expect(slugs).to eq([ "hyhu-terrapin-hyhu", "hyhu-terrapin-hyhu-2" ])
    end

    it "does not raise on the unique slug index" do
      create(:track, show:, title:, songs: [ hyhu ], position: 20, set: "2")
      expect { result }.not_to raise_error
    end
  end
end
