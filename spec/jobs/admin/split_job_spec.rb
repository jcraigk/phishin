require "rails_helper"

RSpec.describe Admin::SplitJob do
  let(:show) { create(:show, date: "2024-07-19") }
  let(:mikes) { create(:song, title: "Mike's Song") }
  let(:hydrogen) { create(:song, title: "I Am Hydrogen") }
  let!(:track) do
    create(
      :track, show:, position: 1, title: "Mike's Song > I Am Hydrogen",
              songs: [ mikes, hydrogen ], slug: "mikes-hydrogen"
    )
  end
  let!(:later_track) { create(:track, show:, position: 2, title: "Weekapaug Groove") }
  let(:admin_job) { create(:admin_job, kind: "split_preview", track:, show:) }
  let(:source) { Rails.root.join("tmp/spec/audio_60s.mp3") }

  before do
    FileUtils.mkdir_p(source.dirname)
    unless File.exist?(source)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=60", "-b:a", "128k", source.to_s,
        exception: true
      )
    end
    track.mp3_audio.attach(
      io: File.open(source), filename: "audio.mp3", content_type: "audio/mpeg"
    )
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  describe "preview" do
    it "completes the admin job" do
      described_class.new.perform(track.id, admin_job.id, 30.0, false)
      expect(admin_job.reload.status).to eq("done")
    end

    it "stores both rendered halves" do
      described_class.new.perform(track.id, admin_job.id, 30.0, false)
      paths = admin_job.reload.payload["audio_paths"]
      expect(paths.size).to eq(2)
      expect(paths.map { File.exist?(it) }).to eq([ true, true ])
    end

    it "renders the first half up to the cut" do
      described_class.new.perform(track.id, admin_job.id, 30.0, false)
      path = admin_job.reload.payload["audio_paths"].first
      expect(probe_duration(path)).to be_within(0.3).of(30.0)
    end

    it "renders the second half from the cut to the end" do
      described_class.new.perform(track.id, admin_job.id, 30.0, false)
      path = admin_job.reload.payload["audio_paths"].last
      expect(probe_duration(path)).to be_within(0.3).of(30.0)
    end

    it "does not create a track" do
      expect { described_class.new.perform(track.id, admin_job.id, 30.0, false) }
        .not_to change { show.tracks.count }
    end

    it "leaves the original track intact" do
      described_class.new.perform(track.id, admin_job.id, 30.0, false)
      expect(track.reload).to have_attributes(
        title: "Mike's Song > I Am Hydrogen", position: 1, slug: "mikes-hydrogen"
      )
    end

    it "leaves the original attachment in place" do
      original_key = track.mp3_audio.blob.key
      described_class.new.perform(track.id, admin_job.id, 30.0, false)
      expect(track.reload.mp3_audio.blob.key).to eq(original_key)
    end

    # The service renders to a path keyed by show date and track slug, so a later
    # render on the same track overwrites it. Each job keeps its own copy or a
    # completed preview would silently start streaming another job's audio.
    it "keeps both halves readable after the job completes" do
      described_class.new.perform(track.id, admin_job.id, 30.0, false)
      paths = admin_job.reload.payload["audio_paths"]

      GC.start
      expect(paths.map { File.size(it).positive? }).to eq([ true, true ])
      expect(paths.map { File.binread(it)[0, 3] }).to eq([ "ID3", "ID3" ])
    end

    it "isolates each job's halves from a later render on the same track" do
      described_class.new.perform(track.id, admin_job.id, 30.0, false)
      first_paths = admin_job.reload.payload["audio_paths"]
      first_bytes = first_paths.map { File.binread(it) }

      second_job = create(:admin_job, kind: "split_preview", track:, show:)
      described_class.new.perform(track.id, second_job.id, 45.0, false)
      second_paths = second_job.reload.payload["audio_paths"]

      expect(second_paths).not_to eq(first_paths)
      expect(first_paths.map { File.binread(it) }).to eq(first_bytes)
      expect(probe_duration(first_paths.first)).to be_within(0.3).of(30.0)
      expect(probe_duration(second_paths.first)).to be_within(0.3).of(45.0)
    end
  end

  describe "apply" do
    it "splits the one track into two" do
      expect { described_class.new.perform(track.id, admin_job.id, 30.0, true) }
        .to change { show.tracks.count }.from(2).to(3)
    end

    it "titles both halves from the segue" do
      described_class.new.perform(track.id, admin_job.id, 30.0, true)
      expect(show.tracks.reload.order(:position).map(&:title))
        .to eq([ "Mike's Song", "I Am Hydrogen", "Weekapaug Groove" ])
    end

    # Position is validated unique per show, so a renumber that collides mid-flight
    # would raise. Asserting the whole show is 1..N catches gaps and duplicates alike.
    it "keeps show positions contiguous from one" do
      described_class.new.perform(track.id, admin_job.id, 30.0, true)
      positions = show.tracks.reload.order(:position).pluck(:position)
      expect(positions).to eq((1..show.tracks.count).to_a)
    end

    it "shifts the track after the split down to make room" do
      expect { described_class.new.perform(track.id, admin_job.id, 30.0, true) }
        .to change { later_track.reload.position }.from(2).to(3)
    end

    it "attaches audio to both halves" do
      described_class.new.perform(track.id, admin_job.id, 30.0, true)
      new_track = show.tracks.reload.find_by(title: "I Am Hydrogen")
      expect([ track.reload.mp3_audio.attached?, new_track.mp3_audio.attached? ])
        .to eq([ true, true ])
    end

    it "gives each half the duration of its part" do
      described_class.new.perform(track.id, admin_job.id, 30.0, true)
      new_track = show.tracks.reload.find_by(title: "I Am Hydrogen")
      expect([ track.reload.duration, new_track.duration ])
        .to all(be_within(500).of(30_000))
    end

    it "stores both applied renders for streaming" do
      described_class.new.perform(track.id, admin_job.id, 30.0, true)
      paths = admin_job.reload.payload["audio_paths"]
      expect(paths.map { File.exist?(it) }).to eq([ true, true ])
      expect(paths.map { probe_duration(it) }).to all(be_within(0.3).of(30.0))
    end

    it "records the new track id on the job" do
      described_class.new.perform(track.id, admin_job.id, 30.0, true)
      new_track = show.tracks.reload.find_by(title: "I Am Hydrogen")
      expect(admin_job.reload.payload["new_track_id"]).to eq(new_track.id)
    end

    describe "derived data" do
      let(:tag) { create(:tag, name: "SBD") }

      before do
        create_list(:like, 2, likable: track)
        create(:track_tag, track:, tag:)
        track.update!(jam_starts_at_second: 40)
      end

      it "duplicates likes onto both halves" do
        described_class.new.perform(track.id, admin_job.id, 30.0, true)
        new_track = show.tracks.reload.find_by(title: "I Am Hydrogen")
        expect([ track.reload.likes.count, new_track.likes.count ]).to eq([ 2, 2 ])
      end

      it "copies an untimestamped tag onto both halves" do
        described_class.new.perform(track.id, admin_job.id, 30.0, true)
        new_track = show.tracks.reload.find_by(title: "I Am Hydrogen")
        expect([ track.reload.tags, new_track.tags ]).to eq([ [ tag ], [ tag ] ])
      end

      it "moves a jam start past the cut onto the second half" do
        described_class.new.perform(track.id, admin_job.id, 30.0, true)
        new_track = show.tracks.reload.find_by(title: "I Am Hydrogen")
        expect([ track.reload.jam_starts_at_second, new_track.jam_starts_at_second ])
          .to eq([ nil, 10 ])
      end
    end

    describe "playlist entries" do
      # A playlist needs two tracks to be valid, so the factory's first entry is
      # repointed at the track under test and the second stands in as the neighbour.
      let!(:playlist) do
        create(:playlist).tap do |list|
          list.playlist_tracks.order(:position).first.update!(track:, position: 1)
        end
      end

      it "turns a full-track entry into one entry per half" do
        described_class.new.perform(track.id, admin_job.id, 30.0, true)
        new_track = show.tracks.reload.find_by(title: "I Am Hydrogen")
        entries = playlist.playlist_tracks.order(:position)
                          .where(track_id: [ track.id, new_track.id ])
        expect(entries.map(&:track_id)).to eq([ track.id, new_track.id ])
      end

      it "clamps the first entry to the cut" do
        described_class.new.perform(track.id, admin_job.id, 30.0, true)
        entry = playlist.playlist_tracks.find_by(track_id: track.id)
        expect(entry.ends_at_second).to eq(30)
      end
    end
  end

  describe "failures" do
    it "fails the admin job on an out-of-range cut" do
      expect { described_class.new.perform(track.id, admin_job.id, 2.0, false) }
        .to raise_error(TrackSplitService::CutOutOfRangeError)
      expect(admin_job.reload.status).to eq("failed")
    end

    it "records the service message on the job" do
      expect { described_class.new.perform(track.id, admin_job.id, 2.0, false) }
        .to raise_error(TrackSplitService::CutOutOfRangeError)
      expect(admin_job.reload.message).to include("under 10.0s")
    end

    it "fails the admin job when the title has no segue" do
      track.update!(title: "Mike's Song")
      expect { described_class.new.perform(track.id, admin_job.id, 30.0, false) }
        .to raise_error(TrackSplitService::TitleError)
      expect(admin_job.reload.status).to eq("failed")
    end

    it "fails the admin job when the track has no audio" do
      track.mp3_audio.detach
      track.update!(audio_status: "missing")
      expect { described_class.new.perform(track.id, admin_job.id, 30.0, false) }
        .to raise_error(TrackSplitService::MissingAudioError)
      expect(admin_job.reload.status).to eq("failed")
    end
  end
end
