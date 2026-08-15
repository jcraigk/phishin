require "rails_helper"

RSpec.describe Admin::ShiftBoundaryJob do
  let(:show) { create(:show, date: "2024-07-19", published: false) }
  let(:ghost) { create(:song, title: "Ghost") }
  let(:free) { create(:song, title: "Free") }
  let!(:first) do
    create(:track, show:, position: 1, title: "Ghost", songs: [ ghost ], slug: "ghost")
  end
  let!(:second) do
    create(:track, show:, position: 2, title: "Free", songs: [ free ], slug: "free")
  end
  let!(:third) { create(:track, show:, position: 3, title: "Weekapaug Groove") }
  let(:admin_job) do
    create(:admin_job, kind: "shift_boundary_preview", track: first, show:)
  end

  before do
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  # Known, DIFFERENT durations: a shift that dropped a side entirely would still
  # look plausible if both sides started out the same length.
  def tone(seconds)
    path = Rails.root.join("tmp/spec/boundary_tone_#{seconds}s.mp3")
    FileUtils.mkdir_p(path.dirname)
    unless File.exist?(path)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=#{seconds}", "-b:a", "128k", path.to_s,
        exception: true
      )
    end
    path
  end

  def attach(track, seconds)
    track.mp3_audio.attach(
      io: File.open(tone(seconds)), filename: "audio.mp3", content_type: "audio/mpeg"
    )
  end

  def probe_duration(path)
    `ffprobe -v error -show_entries format=duration -of csv=p=0 #{path}`.to_f
  end

  def durations
    [ first.reload.duration, second.reload.duration ]
  end

  describe "shifting the boundary later" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    it "grows the first track by the delta" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(first.reload.duration).to be_within(400).of(12_000)
    end

    it "shrinks the second track by the delta" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(second.reload.duration).to be_within(400).of(4_000)
    end

    # The assertion that catches audio dropped at the seam: whatever the
    # boundary does, the pair still holds everything it held before.
    it "preserves the combined duration" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(durations.sum).to be_within(500).of(16_000)
    end

    it "records the new durations on the job" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(admin_job.reload.payload["new_durations"]).to eq([ 12.0, 4.0 ])
    end

    it "records where the boundary landed on the joined clock" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(admin_job.reload.payload["cut_s"]).to eq(12.0)
    end
  end

  describe "shifting the boundary earlier" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    it "shrinks the first track by the delta" do
      described_class.new.perform(first.id, admin_job.id, -2.0, true)
      expect(first.reload.duration).to be_within(400).of(8_000)
    end

    it "grows the second track by the delta" do
      described_class.new.perform(first.id, admin_job.id, -2.0, true)
      expect(second.reload.duration).to be_within(400).of(8_000)
    end

    it "preserves the combined duration" do
      described_class.new.perform(first.id, admin_job.id, -2.0, true)
      expect(durations.sum).to be_within(500).of(16_000)
    end
  end

  describe "applying" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    it "backs up both originals" do
      keys = [ first.mp3_audio.blob.key, second.mp3_audio.blob.key ]
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(admin_job.reload.payload["backup_paths"].map { File.basename(it) })
        .to eq([ "2024-07-19_ghost_#{keys[0]}.mp3", "2024-07-19_free_#{keys[1]}.mp3" ])
    end

    it "writes both backups to disk at their original durations" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      paths = admin_job.reload.payload["backup_paths"]
      expect(paths.map { probe_duration(it).round }).to eq([ 10, 6 ])
    end

    it "gives each track a blob of its own" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(first.reload.mp3_audio.blob.key).not_to eq(second.reload.mp3_audio.blob.key)
    end

    it "leaves both blobs readable" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect {
        first.reload.mp3_audio.blob.download
        second.reload.mp3_audio.blob.download
      }.not_to raise_error
    end

    it "marks both tracks' audio complete" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect([ first.reload.audio_status, second.reload.audio_status ])
        .to eq(%w[complete complete])
    end

    # Matching bitrates join by stream copy, so the only lossy pass is the recut.
    it "reports that the join was not re-encoded" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(admin_job.reload.payload["reencoded"]).to be(false)
    end

    it "completes the admin job" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(admin_job.reload.status).to eq("done")
    end
  end

  # This operation moves a cut point, nothing else. Anything that changed here
  # would be a metadata edit an admin never asked for.
  describe "metadata left untouched" do
    let(:user) { create(:user) }

    before do
      attach(first, 10)
      attach(second, 6)
    end

    it "keeps both titles" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect([ first.reload.title, second.reload.title ]).to eq([ "Ghost", "Free" ])
    end

    it "keeps both slugs" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect([ first.reload.slug, second.reload.slug ]).to eq(%w[ghost free])
    end

    it "keeps every position" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(show.tracks.reload.order(:position).pluck(:position)).to eq([ 1, 2, 3 ])
    end

    it "destroys no track" do
      expect { described_class.new.perform(first.id, admin_job.id, 2.0, true) }
        .not_to change { show.tracks.reload.count }
    end

    it "keeps the songs on both tracks" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect([ first.reload.songs, second.reload.songs ]).to eq([ [ ghost ], [ free ] ])
    end

    it "keeps likes where they were" do
      create(:like, likable: second, user:)
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect([ first.reload.likes.count, second.reload.likes.count ]).to eq([ 0, 1 ])
    end

    it "keeps track tags where they were" do
      create(:track_tag, track: second, tag: create(:tag), starts_at_second: 2)
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(second.reload.track_tags.first.starts_at_second).to eq(2)
    end

    it "keeps playlist entries pointed at the same track" do
      playlist = create(:playlist)
      entry = playlist.playlist_tracks.order(:position).first
      entry.update!(track: second, position: 1)
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(entry.reload.track).to eq(second)
    end

    it "changes no association counts" do
      create(:like, likable: second, user:)
      create(:track_tag, track: first, tag: create(:tag))
      expect { described_class.new.perform(first.id, admin_job.id, 2.0, true) }
        .not_to change { [ Like.count, TrackTag.count, PlaylistTrack.count, Track.count ] }
    end
  end

  describe "preview" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    it "completes the admin job" do
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      expect(admin_job.reload.status).to eq("done")
    end

    it "stores both sides for streaming" do
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      paths = admin_job.reload.payload["audio_paths"]
      expect(paths.map { File.exist?(it) }).to eq([ true, true ])
    end

    it "stores the sides at the shifted durations" do
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      paths = admin_job.reload.payload["audio_paths"]
      expect(paths.map { probe_duration(it).round(1) }).to eq([ 12.0, 4.0 ])
    end

    it "stores the sides at the two audio indices" do
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      expect(admin_job.reload.payload["audio_paths"])
        .to eq([ AdminJobAudio.path_for(admin_job, 0).to_s,
                 AdminJobAudio.path_for(admin_job, 1).to_s ])
    end

    it "leaves both attachments untouched" do
      keys = [ first.mp3_audio.blob.key, second.mp3_audio.blob.key ]
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      expect([ first.reload.mp3_audio.blob.key, second.reload.mp3_audio.blob.key ])
        .to eq(keys)
    end

    it "leaves both durations untouched" do
      before_durations = durations
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      expect(durations).to eq(before_durations)
    end

    it "backs nothing up" do
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      expect(admin_job.reload.payload).not_to have_key("backup_paths")
    end

    it "keeps the renders readable after the job completes" do
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      paths = admin_job.reload.payload["audio_paths"]
      GC.start
      expect(paths.map { File.binread(it)[0, 3] }).to eq(%w[ID3 ID3])
    end
  end

  describe "out-of-range deltas" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    it "refuses a delta that would consume the second track" do
      expect { described_class.new.perform(first.id, admin_job.id, 8.0, true) }
        .to raise_error(described_class::DeltaOutOfRangeError, /allowed range/)
    end

    it "refuses a delta that would consume the first track" do
      expect { described_class.new.perform(first.id, admin_job.id, -12.0, true) }
        .to raise_error(described_class::DeltaOutOfRangeError, /allowed range/)
    end

    it "names the allowed range in the message" do
      expect { described_class.new.perform(first.id, admin_job.id, 8.0, true) }
        .to raise_error(/allowed range is -9\.0s to 5\.0s/)
    end

    it "changes no audio when out of range" do
      before_durations = durations
      expect { described_class.new.perform(first.id, admin_job.id, 8.0, true) }
        .to raise_error(described_class::DeltaOutOfRangeError)
      expect(durations).to eq(before_durations)
    end

    it "fails the admin job" do
      expect { described_class.new.perform(first.id, admin_job.id, 8.0, true) }
        .to raise_error(described_class::DeltaOutOfRangeError)
      expect(admin_job.reload.status).to eq("failed")
    end

    # The stored-duration screen runs before the join, so an impossible delta
    # costs no ffmpeg time at all.
    it "refuses before rendering when the stored durations rule it out" do
      first.update_columns(duration: 10_000)
      second.update_columns(duration: 6_000)
      allow(TrackConcatService).to receive(:call)
      expect { described_class.new.perform(first.id, admin_job.id, 8.0, true) }
        .to raise_error(described_class::DeltaOutOfRangeError, /allowed range is -9\.0s to 5\.0s/)
      expect(TrackConcatService).not_to have_received(:call)
    end
  end

  describe "failures" do
    it "fails on the last track of a show" do
      job = create(:admin_job, kind: "shift_boundary_apply", track: third, show:)
      expect { described_class.new.perform(third.id, job.id, 2.0, true) }
        .to raise_error(described_class::NoNextTrackError)
    end

    it "fails when a side has no audio" do
      attach(first, 10)
      expect { described_class.new.perform(first.id, admin_job.id, 2.0, true) }
        .to raise_error(described_class::MissingAudioError)
    end

    it "changes nothing when a side has no audio" do
      attach(first, 10)
      key = first.mp3_audio.blob.key
      expect { described_class.new.perform(first.id, admin_job.id, 2.0, true) }
        .to raise_error(described_class::MissingAudioError)
      expect(first.reload.mp3_audio.blob.key).to eq(key)
    end

    # A row can claim its audio is attached while the file is gone from storage.
    it "fails when a blob is missing from storage" do
      attach(first, 10)
      attach(second, 6)
      second.mp3_audio.blob.service.delete(second.mp3_audio.blob.key)
      expect { described_class.new.perform(first.id, admin_job.id, 2.0, true) }
        .to raise_error(TrackConcatService::MissingAudioError)
    end
  end
end
