require "rails_helper"

RSpec.describe Admin::CombineTracksJob do
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
  let(:admin_job) { create(:admin_job, kind: "combine_preview", track: second, show:) }

  before do
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  # Known, DIFFERENT durations: a join that silently kept only one side would
  # still look plausible with two equal-length tones.
  def tone(seconds)
    path = Rails.root.join("tmp/spec/combine_tone_#{seconds}s.mp3")
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

  describe "metadata merge" do
    it "joins the titles with a segue" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.title).to eq("Ghost > Free")
    end

    it "unions the songs of both tracks" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.songs).to contain_exactly(ghost, free)
    end

    it "does not duplicate a song present on both tracks" do
      second.songs = [ ghost, free ]
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.songs).to contain_exactly(ghost, free)
    end

    it "destroys the merged track" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(Track.exists?(second.id)).to be(false)
    end

    it "renumbers the show contiguously from one" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(show.tracks.reload.order(:position).pluck(:position)).to eq([ 1, 2 ])
    end

    it "compacts the track below the merge up a position" do
      expect { described_class.new.perform(second.id, admin_job.id, true) }
        .to change { third.reload.position }.from(3).to(2)
    end

    it "regenerates the slug on an unpublished show" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.slug).to eq("ghost-free")
    end

    # A published show's track URLs are already out in the world.
    it "keeps the slug on a published show" do
      show.update!(published: true)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.slug).to eq("ghost")
    end
  end

  describe "audio when both tracks have audio" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    # The headline assertion. The inline endpoint this job replaces kept only the
    # first track's file and destroyed the second's, so this case used to yield a
    # 10s track and six seconds of archive audio was gone with no backup.
    it "yields one track holding both tracks' audio" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.duration).to be_within(500).of(16_000)
    end

    it "leaves the show with one fewer track" do
      expect { described_class.new.perform(second.id, admin_job.id, true) }
        .to change { show.tracks.reload.count }.from(3).to(2)
    end

    it "backs up both originals before replacing the audio" do
      first_key = first.mp3_audio.blob.key
      second_key = second.mp3_audio.blob.key
      described_class.new.perform(second.id, admin_job.id, true)
      expect(admin_job.reload.payload["backup_paths"].map { File.basename(it) })
        .to contain_exactly(
          "2024-07-19_ghost_#{first_key}.mp3", "2024-07-19_free_#{second_key}.mp3"
        )
    end

    it "writes both backups to disk" do
      described_class.new.perform(second.id, admin_job.id, true)
      paths = admin_job.reload.payload["backup_paths"]
      expect(paths.map { File.exist?(it) }).to eq([ true, true ])
    end

    it "keeps the backups at their original durations" do
      described_class.new.perform(second.id, admin_job.id, true)
      paths = admin_job.reload.payload["backup_paths"]
      expect(paths.map { probe_duration(it).round })
        .to contain_exactly(10, 6)
    end

    # Matching bitrates concat by stream copy, so the archive never takes a
    # second generation of MP3 loss.
    it "reports that matching bitrates were not re-encoded" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(admin_job.reload.payload["reencoded"]).to be(false)
    end

    it "records both source durations on the job" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(admin_job.reload.payload["source_durations"]).to eq([ 10.0, 6.0 ])
    end

    it "leaves the survivor with a blob of its own" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.mp3_audio).to be_attached
    end

    it "marks the survivor's audio complete" do
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.audio_status).to eq("complete")
    end
  end

  describe "audio when only one track has audio" do
    it "keeps the survivor's own audio when only it has any" do
      attach(first, 10)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.duration).to be_within(500).of(10_000)
    end

    it "adopts the second track's audio when only it has any" do
      attach(second, 6)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.mp3_audio).to be_attached
    end

    it "gives the survivor the adopted duration" do
      attach(second, 6)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.duration).to be_within(500).of(6_000)
    end

    # destroy! purges the attachment it takes with the row, so the survivor has
    # to hold a copy rather than the blob the destroyed track pointed at.
    it "leaves the adopted audio readable after the merged row is gone" do
      attach(second, 6)
      described_class.new.perform(second.id, admin_job.id, true)
      expect { first.reload.mp3_audio.blob.download }.not_to raise_error
    end

    it "does not hand the survivor the destroyed track's blob" do
      attach(second, 6)
      key = second.mp3_audio.blob.key
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.mp3_audio.blob.key).not_to eq(key)
    end

    it "backs up the adopted original" do
      attach(second, 6)
      key = second.mp3_audio.blob.key
      described_class.new.perform(second.id, admin_job.id, true)
      expect(admin_job.reload.payload["backup_paths"].map { File.basename(it) })
        .to eq([ "2024-07-19_free_#{key}.mp3" ])
    end

    it "does not join when only one side has audio" do
      attach(first, 10)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(admin_job.reload.payload["joined_audio"]).to be(false)
    end
  end

  describe "associations carried onto the survivor" do
    let(:user) { create(:user) }

    before do
      attach(first, 10)
      attach(second, 6)
    end

    it "keeps a like on the merged track" do
      create(:like, likable: second, user:)
      expect { described_class.new.perform(second.id, admin_job.id, true) }
        .not_to change(Like, :count)
    end

    it "repoints the like at the survivor" do
      like = create(:like, likable: second, user:)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(like.reload.likable).to eq(first)
    end

    # (user, likable) is unique, so the same listener liking both tracks has to
    # drop to one like rather than raising.
    it "drops a duplicate like from a user who liked both tracks" do
      create(:like, likable: first, user:)
      create(:like, likable: second, user:)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.likes.count).to eq(1)
    end

    it "keeps distinct users' likes from both tracks" do
      create(:like, likable: first, user:)
      create(:like, likable: second, user: create(:user))
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.likes.count).to eq(2)
    end

    it "moves a tag from the merged track onto the survivor" do
      tag = create(:tag, name: "Jamcharts")
      create(:track_tag, track: second, tag:)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.tags).to eq([ tag ])
    end

    # An untimestamped tag describes the whole recording, so the same tag on both
    # sides is one tag on the survivor, not two.
    it "does not duplicate an untimestamped tag present on both tracks" do
      tag = create(:tag, name: "SBD")
      create(:track_tag, track: first, tag:)
      create(:track_tag, track: second, tag:)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.track_tags.count).to eq(1)
    end

    # A timestamp on the merged track pointed into audio that now begins ten
    # seconds in, so it is rebased or it describes the wrong moment.
    it "rebases a timestamped tag onto the joined clock" do
      create(:track_tag, track: second, tag: create(:tag), starts_at_second: 2,
                         ends_at_second: 4)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(first.reload.track_tags.first)
        .to have_attributes(starts_at_second: 12, ends_at_second: 14)
    end

    it "keeps a playlist entry for the merged track" do
      playlist = create(:playlist)
      entry = playlist.playlist_tracks.order(:position).first
      entry.update!(track: second, position: 1)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(entry.reload.track).to eq(first)
    end

    it "does not drop the playlist entry" do
      playlist = create(:playlist)
      playlist.playlist_tracks.order(:position).first.update!(track: second, position: 1)
      expect { described_class.new.perform(second.id, admin_job.id, true) }
        .not_to change(PlaylistTrack, :count)
    end

    # A whole-track entry for the merged track has to keep playing the same
    # audio, which now starts ten seconds into the survivor.
    it "rebases a playlist entry onto the joined clock" do
      playlist = create(:playlist)
      entry = playlist.playlist_tracks.order(:position).first
      entry.update!(track: second, position: 1)
      described_class.new.perform(second.id, admin_job.id, true)
      expect(entry.reload.starts_at_second).to eq(10)
    end
  end

  describe "preview" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    it "completes the admin job" do
      described_class.new.perform(second.id, admin_job.id, false)
      expect(admin_job.reload.status).to eq("done")
    end

    it "stores the joined render for streaming" do
      described_class.new.perform(second.id, admin_job.id, false)
      path = admin_job.reload.payload["audio_paths"].first
      expect(File.exist?(path)).to be(true)
    end

    it "renders the full joined duration" do
      described_class.new.perform(second.id, admin_job.id, false)
      path = admin_job.reload.payload["audio_paths"].first
      expect(probe_duration(path)).to be_within(0.3).of(16.0)
    end

    it "destroys no track" do
      expect { described_class.new.perform(second.id, admin_job.id, false) }
        .not_to change { show.tracks.reload.count }
    end

    it "leaves both titles alone" do
      described_class.new.perform(second.id, admin_job.id, false)
      expect([ first.reload.title, second.reload.title ]).to eq([ "Ghost", "Free" ])
    end

    it "leaves both attachments untouched" do
      keys = [ first.mp3_audio.blob.key, second.mp3_audio.blob.key ]
      described_class.new.perform(second.id, admin_job.id, false)
      expect([ first.reload.mp3_audio.blob.key, second.reload.mp3_audio.blob.key ])
        .to eq(keys)
    end

    it "backs nothing up" do
      described_class.new.perform(second.id, admin_job.id, false)
      expect(admin_job.reload.payload).not_to have_key("backup_paths")
    end

    it "keeps the render readable after the job completes" do
      described_class.new.perform(second.id, admin_job.id, false)
      path = admin_job.reload.payload["audio_paths"].first
      GC.start
      expect(File.binread(path)[0, 3]).to eq("ID3")
    end
  end

  describe "failures" do
    it "fails the admin job on the first track of a show" do
      job = create(:admin_job, kind: "combine_apply", track: first, show:)
      expect { described_class.new.perform(first.id, job.id, true) }
        .to raise_error(described_class::NoPreviousTrackError)
      expect(job.reload.status).to eq("failed")
    end

    it "destroys nothing when there is no previous track" do
      job = create(:admin_job, kind: "combine_apply", track: first, show:)
      expect { described_class.new.perform(first.id, job.id, true) }
        .to raise_error(described_class::NoPreviousTrackError)
      expect(show.tracks.reload.count).to eq(3)
    end

    # A row can say its audio is attached while the file is gone from storage.
    # The job has to fail rather than destroy a track over a half-done join.
    it "fails and destroys nothing when a blob is missing from storage" do
      attach(first, 10)
      attach(second, 6)
      second.mp3_audio.blob.service.delete(second.mp3_audio.blob.key)
      expect { described_class.new.perform(second.id, admin_job.id, true) }
        .to raise_error(TrackConcatService::MissingAudioError)
      expect(show.tracks.reload.count).to eq(3)
    end
  end
end
