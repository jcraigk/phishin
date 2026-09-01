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

    it "backs up both originals under stamped names" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      names = admin_job.reload.payload["backup_paths"].map { File.basename(it) }
      expect(names[0]).to match(/\A2024-07-19_ghost_shift_boundary_\d{8}-\d{6}\.mp3\z/)
      expect(names[1]).to match(/\A2024-07-19_free_shift_boundary_\d{8}-\d{6}\.mp3\z/)
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

    it "reports that the join was not re-encoded" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(admin_job.reload.payload["reencoded"]).to be(false)
    end

    it "completes the admin job" do
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(admin_job.reload.status).to eq("done")
    end
  end

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

    it "moves a track tag with the audio it describes" do
      create(:track_tag, track: second, tag: create(:tag), starts_at_second: 2)
      described_class.new.perform(first.id, admin_job.id, 2.0, true)
      expect(second.reload.track_tags.first.starts_at_second).to eq(0)
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

  describe "renaming both sides" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    def shift(titles, delta: 2.0, apply: true)
      described_class.new.perform(first.id, admin_job.id, delta, apply, titles)
    end

    it "writes both new titles" do
      shift({ "first" => "Tweezer", "second" => "Slave to the Traffic Light" })
      expect([ first.reload.title, second.reload.title ])
        .to eq([ "Tweezer", "Slave to the Traffic Light" ])
    end

    it "regenerates both slugs from the new titles" do
      shift({ "first" => "Tweezer", "second" => "Slave to the Traffic Light" })
      expect([ first.reload.slug, second.reload.slug ])
        .to eq(%w[tweezer slave-to-the-traffic-light])
    end

    it "renames only the side it was given" do
      shift({ "second" => "Tweezer" })
      expect([ first.reload.title, second.reload.title ]).to eq([ "Ghost", "Tweezer" ])
    end

    it "leaves the untouched side's slug alone" do
      shift({ "second" => "Tweezer" })
      expect(first.reload.slug).to eq("ghost")
    end

    it "still moves the boundary" do
      shift({ "first" => "Tweezer", "second" => "Mike's Song" })
      expect(first.reload.duration).to be_within(400).of(12_000)
    end

    it "still preserves the combined duration" do
      shift({ "first" => "Tweezer", "second" => "Mike's Song" })
      expect(durations.sum).to be_within(500).of(16_000)
    end

    it "reports the renames on the job" do
      shift({ "first" => "Tweezer" })
      expect(admin_job.reload.payload["titles_changed"])
        .to eq([ { "track_id" => first.id, "from" => "Ghost", "to" => "Tweezer" } ])
    end

    it "reports the reslugs on the job" do
      shift({ "first" => "Tweezer" })
      expect(admin_job.reload.payload["reslugged"])
        .to eq([ { "track_id" => first.id, "from" => "ghost", "to" => "tweezer" } ])
    end

    it "reports that the slugs were not frozen" do
      shift({ "first" => "Tweezer" })
      expect(admin_job.reload.payload["slug_frozen"]).to be(false)
    end

    it "carries the new title onto the attached audio filename" do
      shift({ "first" => "Tweezer" })
      expect(first.reload.mp3_audio.blob.filename.to_s)
        .to eq("Phish 2024-07-19 01 Tweezer.mp3")
    end

    it "leaves the songs pointed where they were" do
      shift({ "first" => "Tweezer" })
      expect(first.reload.songs).to eq([ ghost ])
    end

    it "changes no positions" do
      shift({ "first" => "Tweezer", "second" => "Mike's Song" })
      expect(show.tracks.reload.order(:position).pluck(:position)).to eq([ 1, 2, 3 ])
    end

    it "accepts symbol keys from a direct caller" do
      shift({ first: "Tweezer" })
      expect(first.reload.title).to eq("Tweezer")
    end

    it "trims surrounding whitespace off a title" do
      shift({ "first" => "  Tweezer  " })
      expect(first.reload.title).to eq("Tweezer")
    end

    it "writes nothing on a preview" do
      shift({ "first" => "Tweezer" }, apply: false)
      expect([ first.reload.title, first.reload.slug ]).to eq([ "Ghost", "ghost" ])
    end
  end

  describe "renaming into a title another track already has" do
    let!(:fourth) do
      create(:track, show:, position: 4, title: "Tweezer", slug: "tweezer")
    end

    before do
      attach(first, 10)
      attach(second, 6)
    end

    def shift(titles)
      described_class.new.perform(first.id, admin_job.id, 2.0, true, titles)
    end

    it "raises no unique violation" do
      expect { shift({ "second" => "Tweezer" }) }.not_to raise_error
    end

    it "numbers the duplicate slugs by position" do
      shift({ "second" => "Tweezer" })
      expect(show.tracks.reload.order(:position).pluck(:title, :slug))
        .to eq([ [ "Ghost", "ghost" ],
                 [ "Tweezer", "tweezer" ],
                 [ "Weekapaug Groove", "weekapaug-groove" ],
                 [ "Tweezer", "tweezer-2" ] ])
    end

    it "reslugs the sibling that was never named in the request" do
      shift({ "second" => "Tweezer" })
      expect(admin_job.reload.payload["reslugged"])
        .to contain_exactly(
          { "track_id" => second.id, "from" => "free", "to" => "tweezer" },
          { "track_id" => fourth.id, "from" => "tweezer", "to" => "tweezer-2" }
        )
    end

    it "keeps every slug distinct" do
      shift({ "second" => "Tweezer" })
      slugs = show.tracks.reload.pluck(:slug)
      expect(slugs.uniq.size).to eq(slugs.size)
    end

    it "leaves no track parked on a temporary slug" do
      shift({ "second" => "Tweezer" })
      expect(show.tracks.reload.pluck(:slug).grep(/\Atmp-/)).to be_empty
    end

    it "renumbers the rows left behind when a duplicate title is vacated" do
      second.update!(title: "Tweezer", slug: "tweezer-2")
      fourth.update_columns(slug: "tweezer-3")
      create(:track, show:, position: 5, title: "Tweezer", slug: "tweezer-4")
      described_class.new.perform(first.id, admin_job.id, 2.0, true, { "first" => "Tweezer" })
      expect(show.tracks.reload.order(:position).pluck(:title, :slug))
        .to eq([ [ "Tweezer", "tweezer" ],
                 [ "Tweezer", "tweezer-2" ],
                 [ "Weekapaug Groove", "weekapaug-groove" ],
                 [ "Tweezer", "tweezer-3" ],
                 [ "Tweezer", "tweezer-4" ] ])
    end
  end

  describe "renaming the first side onto the second side's title" do
    before do
      first.update!(title: "Wild Child")
      first.update_columns(slug: "wild-child")
      second.update!(title: "Bertha")
      second.update_columns(slug: "bertha")
      attach(first, 10)
      attach(second, 6)
    end

    def shift
      described_class.new.perform(first.id, admin_job.id, 2.0, true, { "first" => "Bertha" })
    end

    it "has both tracks computing the same slug beforehand" do
      renamed = Track.find(first.id).tap { it.title = "Bertha" }
      expect(TrackSlugGenerator.call(renamed)).to eq(TrackSlugGenerator.call(second))
    end

    it "raises no unique violation" do
      expect { shift }.not_to raise_error
    end

    it "gives the renamed track the bare slug" do
      shift
      expect(first.reload.slug).to eq("bertha")
    end

    it "renumbers the untouched sibling to bertha-2" do
      shift
      expect(second.reload.slug).to eq("bertha-2")
    end

    it "keeps every slug in the show distinct" do
      shift
      slugs = show.tracks.reload.pluck(:slug)
      expect(slugs.uniq.size).to eq(slugs.size)
    end

    it "reports both slug moves, including the untouched sibling's" do
      shift
      expect(admin_job.reload.payload["reslugged"]).to contain_exactly(
        { "track_id" => first.id, "from" => "wild-child", "to" => "bertha" },
        { "track_id" => second.id, "from" => "bertha", "to" => "bertha-2" }
      )
    end

    it "still moves the boundary" do
      shift
      expect(first.reload.duration).to be_within(400).of(12_000)
    end
  end

  describe "renaming away from a duplicated title" do
    before do
      show.tracks.order(:position).each_with_index do |track, i|
        track.update_columns(slug: "setup-tmp-#{i}")
      end
      first.update!(title: "Bertha")
      first.update_columns(slug: "bertha")
      second.update!(title: "Bertha")
      second.update_columns(slug: "bertha-2")
      third.update_columns(slug: "weekapaug-groove")
      attach(first, 10)
      attach(second, 6)
    end

    def shift
      described_class.new.perform(
        first.id, admin_job.id, 2.0, true, { "first" => "Scarlet Begonias" }
      )
    end

    it "lets the untouched sibling drop its suffix" do
      shift
      expect(second.reload.slug).to eq("bertha")
    end

    it "slugs the renamed track from its new title" do
      shift
      expect(first.reload.slug).to eq("scarlet-begonias")
    end

    it "leaves an unrelated track's slug alone" do
      shift
      expect(third.reload.slug).to eq("weekapaug-groove")
    end

    it "reports the sibling's move" do
      shift
      expect(admin_job.reload.payload["reslugged"]).to include(
        { "track_id" => second.id, "from" => "bertha-2", "to" => "bertha" }
      )
    end

    it "keeps every slug distinct" do
      shift
      slugs = show.tracks.reload.pluck(:slug)
      expect(slugs.uniq.size).to eq(slugs.size)
    end

    it "keeps the stale suffix when the show is published" do
      show.update!(published: true)
      shift
      expect([ first.reload.slug, second.reload.slug ]).to eq(%w[bertha bertha-2])
    end
  end

  describe "renaming on a published show" do
    before do
      show.update!(published: true)
      attach(first, 10)
      attach(second, 6)
    end

    def shift(titles)
      described_class.new.perform(first.id, admin_job.id, 2.0, true, titles)
    end

    it "still writes the new titles" do
      shift({ "first" => "Tweezer", "second" => "Mike's Song" })
      expect([ first.reload.title, second.reload.title ])
        .to eq([ "Tweezer", "Mike's Song" ])
    end

    it "keeps both slugs byte-identical" do
      before_slugs = [ first.slug, second.slug ]
      shift({ "first" => "Tweezer", "second" => "Mike's Song" })
      expect([ first.reload.slug, second.reload.slug ]).to eq(before_slugs)
    end

    it "keeps every other slug in the show untouched" do
      before_slugs = show.tracks.reload.order(:position).pluck(:slug)
      shift({ "first" => "Tweezer", "second" => "Mike's Song" })
      expect(show.tracks.reload.order(:position).pluck(:slug)).to eq(before_slugs)
    end

    it "reports that the slugs were frozen" do
      shift({ "first" => "Tweezer" })
      expect(admin_job.reload.payload["slug_frozen"]).to be(true)
    end

    it "reports no reslugs" do
      shift({ "first" => "Tweezer" })
      expect(admin_job.reload.payload["reslugged"]).to eq([])
    end

    it "still moves the boundary" do
      shift({ "first" => "Tweezer" })
      expect(first.reload.duration).to be_within(400).of(12_000)
    end
  end

  describe "blank titles" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    def shift(titles)
      described_class.new.perform(first.id, admin_job.id, 2.0, true, titles)
    end

    it "refuses an empty title" do
      expect { shift({ "first" => "" }) }
        .to raise_error(described_class::BlankTitleError, /blank title for first/)
    end

    it "refuses a whitespace-only title" do
      expect { shift({ "second" => "   " }) }
        .to raise_error(described_class::BlankTitleError, /blank title for second/)
    end

    it "names both sides when both are blank" do
      expect { shift({ "first" => "", "second" => "" }) }
        .to raise_error(described_class::BlankTitleError, /first and second/)
    end

    it "changes no title" do
      expect { shift({ "first" => "" }) }.to raise_error(described_class::BlankTitleError)
      expect(first.reload.title).to eq("Ghost")
    end

    it "changes no audio" do
      before_durations = durations
      expect { shift({ "first" => "" }) }.to raise_error(described_class::BlankTitleError)
      expect(durations).to eq(before_durations)
    end

    it "refuses before rendering anything" do
      allow(TrackConcatService).to receive(:call)
      expect { shift({ "first" => "" }) }.to raise_error(described_class::BlankTitleError)
      expect(TrackConcatService).not_to have_received(:call)
    end
  end

  describe "a failed render with a valid rename" do
    before do
      attach(first, 10)
      attach(second, 6)
      allow(Open3).to receive(:capture3).and_call_original
      allow(Open3).to receive(:capture3)
        .with("ffmpeg", *any_args)
        .and_return([ "", "boom", instance_double(Process::Status, success?: false) ])
    end

    def shift_expecting_failure(titles)
      expect {
        described_class.new.perform(first.id, admin_job.id, 2.0, true, titles)
      }.to raise_error(TrackConcatService::Error)
    end

    it "leaves both old titles in place" do
      shift_expecting_failure({ "first" => "Tweezer", "second" => "Mike's Song" })
      expect([ first.reload.title, second.reload.title ]).to eq([ "Ghost", "Free" ])
    end

    it "leaves both old slugs in place" do
      shift_expecting_failure({ "first" => "Tweezer", "second" => "Mike's Song" })
      expect([ first.reload.slug, second.reload.slug ]).to eq(%w[ghost free])
    end

    it "fails the admin job" do
      shift_expecting_failure({ "first" => "Tweezer" })
      expect(admin_job.reload.status).to eq("failed")
    end

    it "records no rename on the job" do
      shift_expecting_failure({ "first" => "Tweezer" })
      expect(admin_job.reload.payload).not_to have_key("titles_changed")
    end
  end

  describe "song drift" do
    before do
      attach(first, 10)
      attach(second, 6)
    end

    def shift(titles)
      described_class.new.perform(first.id, admin_job.id, 2.0, true, titles)
    end

    it "flags a renamed track whose title no longer matches any of its songs" do
      shift({ "first" => "Tweezer" })
      expect(admin_job.reload.payload["song_drift"])
        .to eq([ { "track_id" => first.id, "title" => "Tweezer",
                   "song_titles" => [ "Ghost" ] } ])
    end

    it "flags nothing when the new title still matches a song" do
      first.songs = [ ghost, free ]
      shift({ "first" => "Free" })
      expect(admin_job.reload.payload["song_drift"]).to eq([])
    end

    it "applies the rename anyway" do
      shift({ "first" => "Tweezer > Ghost" })
      expect(first.reload.title).to eq("Tweezer > Ghost")
    end

    it "leaves the association alone" do
      shift({ "first" => "Tweezer" })
      expect(first.reload.songs).to eq([ ghost ])
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

    it "fails when a blob is missing from storage" do
      attach(first, 10)
      attach(second, 6)
      second.mp3_audio.blob.service.delete(second.mp3_audio.blob.key)
      expect { described_class.new.perform(first.id, admin_job.id, 2.0, true) }
        .to raise_error(TrackConcatService::MissingAudioError)
    end
  end
end
