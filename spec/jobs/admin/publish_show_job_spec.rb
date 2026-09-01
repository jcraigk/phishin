require "rails_helper"

RSpec.describe Admin::PublishShowJob do
  let(:show) { create(:show, date: "2025-08-01", published: false) }
  let(:admin_job) { create(:admin_job, kind: "publish", show:) }
  let!(:debut_tag) { create(:tag, name: "Debut") }
  let!(:bustout_tag) { create(:tag, name: "Bustout") }

  def attach_audio(track)
    track.mp3_audio.attach(
      io: StringIO.new("mp3"), filename: "a.mp3", content_type: "audio/mpeg"
    )
    track.png_waveform.attach(
      io: StringIO.new("png"), filename: "a.png", content_type: "image/png"
    )
    track.update!(duration: 100_000, audio_status: "complete")
  end

  def ready_show
    show.cover_art.attach(
      io: StringIO.new("img"), filename: "a.png", content_type: "image/png"
    )
    show.album_cover.attach(
      io: StringIO.new("img"), filename: "b.png", content_type: "image/png"
    )
    attach_audio(create(:track, show:, position: 1, songs: [ create(:song) ]))
    show.reload
  end

  before do
    allow(LoreSyncService).to receive(:call)
    allow(Rails.cache).to receive(:clear)
    ready_show
  end

  describe "the publish pipeline" do
    it "publishes the show" do
      described_class.new.perform(show.id, admin_job.id)
      expect(show.reload.published).to be(true)
    end

    it "marks the admin job done" do
      described_class.new.perform(show.id, admin_job.id)
      expect(admin_job.reload.status).to eq("done")
      expect(admin_job.progress).to eq(100)
    end

    it "runs the side effects before flipping the published flag" do
      order = []
      allow(GapService).to receive(:call) { order << :gap }
      allow(DebutTagService).to receive(:call) { order << :debut }
      allow(BustoutTagService).to receive(:call) { order << :bustout }
      allow(LoreSyncService).to receive(:call) { order << :lore }
      allow(show.class).to receive(:find).and_return(show)
      allow(show).to receive(:update!).and_wrap_original do |method, *args|
        order << :publish
        method.call(*args)
      end

      described_class.new.perform(show.id, admin_job.id)

      expect(order).to eq([ :gap, :debut, :bustout, :lore, :publish ])
    end

    it "computes gaps including the previous performances of each song" do
      allow(GapService).to receive(:call)
      described_class.new.perform(show.id, admin_job.id)
      expect(GapService).to have_received(:call).with(show, update_previous: true)
    end

    it "syncs lore for the show's date" do
      described_class.new.perform(show.id, admin_job.id)
      expect(LoreSyncService).to have_received(:call).with(date: "2025-08-01")
    end

    it "clears the Rails cache" do
      described_class.new.perform(show.id, admin_job.id)
      expect(Rails.cache).to have_received(:clear)
    end
  end

  describe "real service effects" do
    it "applies the debut tag to a song performed for the first time" do
      described_class.new.perform(show.id, admin_job.id)
      expect(show.tracks.first.track_tags.map(&:tag)).to include(debut_tag)
    end

    it "applies the bustout tag when the gap since the last performance is large" do
      song = show.tracks.first.songs.first
      101.times do |n|
        old = create(:show, date: Date.new(2020, 1, 1) + n.days, published: true)
        create(:track, show: old, position: 1, songs: n.zero? ? [ song ] : [ create(:song) ])
      end

      described_class.new.perform(show.id, admin_job.id)

      expect(show.tracks.first.track_tags.map(&:tag)).to include(bustout_tag)
    end
  end

  describe "the announcement" do
    it "creates one naming the show" do
      described_class.new.perform(show.id, admin_job.id)
      announcement = Announcement.last
      expect(announcement.title).to eq("New content: 2025-08-01 at #{show.venue_name}")
      expect(announcement.description)
        .to eq("A new show has been added: 2025-08-01 at #{show.venue_name}")
      expect(announcement.url).to eq("#{App.base_url}/2025-08-01")
    end

    it "matches what the CLI importer would have created" do
      described_class.new.perform(show.id, admin_job.id)
      show_name = "#{show.date} at #{show.venue_name}"
      expect(Announcement.last).to have_attributes(
        title: "New content: #{show_name}",
        description: "A new show has been added: #{show_name}",
        url: "#{App.base_url}/#{show.date}"
      )
    end

    it "is not duplicated when the job runs twice" do
      described_class.new.perform(show.id, admin_job.id)
      second_job = create(:admin_job, kind: "publish", show:)

      expect {
        described_class.new.perform(show.id, second_job.id)
      }.not_to change(Announcement, :count)
    end

    it "leaves an unrelated announcement for another show alone" do
      create(:announcement, url: "#{App.base_url}/1995-12-31")
      expect {
        described_class.new.perform(show.id, admin_job.id)
      }.to change(Announcement, :count).by(1)
    end
  end

  describe "an already published show" do
    it "re-runs the pipeline without erroring" do
      show.update!(published: true)
      described_class.new.perform(show.id, admin_job.id)
      expect(admin_job.reload.status).to eq("done")
      expect(show.reload.published).to be(true)
    end
  end

  describe "a show that is not ready" do
    it "refuses to publish and records why" do
      show.tracks.first.mp3_audio.detach

      expect {
        described_class.new.perform(show.id, admin_job.id)
      }.to raise_error(Admin::PublishShowJob::NotReadyError, /no audio/)

      expect(show.reload.published).to be(false)
      expect(admin_job.reload.status).to eq("failed")
      expect(admin_job.message).to include("no audio")
    end

    it "creates no announcement" do
      show.update!(venue: nil)
      expect {
        described_class.new.perform(show.id, admin_job.id)
      }.to raise_error(Admin::PublishShowJob::NotReadyError)
      expect(Announcement.count).to eq(0)
    end
  end

  describe "a side effect that raises" do
    before { allow(GapService).to receive(:call).and_raise("gap blew up") }

    it "leaves the show unpublished" do
      expect {
        described_class.new.perform(show.id, admin_job.id)
      }.to raise_error("gap blew up")
      expect(show.reload.published).to be(false)
    end

    it "records the failure on the admin job and re-raises for Sidekiq" do
      expect {
        described_class.new.perform(show.id, admin_job.id)
      }.to raise_error("gap blew up")
      expect(admin_job.reload.status).to eq("failed")
      expect(admin_job.message).to eq("gap blew up")
    end

    it "creates no announcement" do
      expect {
        described_class.new.perform(show.id, admin_job.id)
      }.to raise_error("gap blew up")
      expect(Announcement.count).to eq(0)
    end
  end

  describe "staged audio cleanup" do
    def audio_blob(name)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(name), filename: "#{name}.mp3", content_type: "audio/mpeg"
      )
    end

    it "clears staged audio without purging a blob a track still uses" do
      shared = audio_blob("shared")
      orphan = audio_blob("orphan")
      show.staged_audio.attach(shared)
      show.staged_audio.attach(orphan)
      show.tracks.first.mp3_audio.attach(shared)

      described_class.new.perform(show.id, admin_job.id)

      expect(show.reload.staged_audio.count).to eq(0)
      expect(ActiveStorage::Blob.exists?(shared.id)).to be(true)
      expect(ActiveStorage::Blob.exists?(orphan.id)).to be(false)
    end
  end

  describe "public visibility" do
    it "makes the show reachable through the published scope" do
      expect(Show.published.find_by(date: "2025-08-01")).to be_nil
      described_class.new.perform(show.id, admin_job.id)
      expect(Show.published.find_by(date: "2025-08-01")).to eq(show)
    end
  end
end
