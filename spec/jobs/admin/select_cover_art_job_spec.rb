require "rails_helper"
require "mini_magick"

# Nothing here reaches OpenAI: selection promotes an image the show already
# holds, so the billed image endpoints are never constructed. The examples that
# stub AlbumCoverService and apply_id3_tags do so for speed, not for cost -- the
# "end to end" group below runs both for real.
RSpec.describe Admin::SelectCoverArtJob do
  let(:show) do
    create(:show, date: "2024-07-19", venue: create(:venue, name: "Hampton Coliseum"))
  end
  let(:admin_job) { create(:admin_job, kind: "cover_art_select", show:) }
  let(:image_path) { Rails.root.join("spec/fixtures/files/cover-art-large.jpg") }

  let!(:winner) { attach_candidate("winner.jpg") }
  let!(:loser) { attach_candidate("loser.jpg") }

  def attach_candidate(filename)
    show.cover_art_candidates.attach(
      io: File.open(image_path), filename:, content_type: "image/jpeg"
    )
    show.cover_art_candidates_attachments.reload.last.blob
  end

  describe "applying the winner" do
    before do
      allow(AlbumCoverService).to receive(:call)
      allow_any_instance_of(Track).to receive(:apply_id3_tags) # rubocop:disable RSpec/AnyInstance
    end

    it "attaches the winner as the show's cover art" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(show.reload.cover_art.blob).to eq(winner)
    end

    it "clears every candidate" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(show.reload.cover_art_candidates.count).to eq(0)
    end

    it "keeps the winner's blob" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(ActiveStorage::Blob.exists?(winner.id)).to be(true)
    end

    it "purges the passed-over candidate's blob" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(ActiveStorage::Blob.exists?(loser.id)).to be(false)
    end

    it "composites the album cover" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(AlbumCoverService).to have_received(:call).with(show)
    end

    it "completes the admin job" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(admin_job.reload).to have_attributes(status: "done", progress: 100)
    end

    it "raises on a blob key the show does not own" do
      other = ActiveStorage::Blob.create_and_upload!(
        io: File.open(image_path), filename: "elsewhere.jpg", content_type: "image/jpeg"
      )
      expect { described_class.new.perform(show.id, admin_job.id, other.key, 0) }
        .to raise_error(/Unknown cover art candidate/)
    end

    it "fails the admin job on an unknown blob key" do
      expect { described_class.new.perform(show.id, admin_job.id, "nope", 0) }
        .to raise_error(/Unknown cover art candidate/)
      expect(admin_job.reload.status).to eq("failed")
    end

    it "leaves the candidates in place when the key is unknown" do
      expect { described_class.new.perform(show.id, admin_job.id, "nope", 0) }
        .to raise_error(/Unknown cover art candidate/)
      expect(show.reload.cover_art_candidates.count).to eq(2)
    end
  end

  # A parent-linked show is offered its parent's own cover art blob as a
  # candidate, so a purge of a passed-over candidate would take the parent's art
  # with it.
  describe "a candidate blob shared with another show" do
    let(:parent) { create(:show, date: "2024-07-18") }

    before do
      allow(AlbumCoverService).to receive(:call)
      allow_any_instance_of(Track).to receive(:apply_id3_tags) # rubocop:disable RSpec/AnyInstance
      parent.cover_art.attach(loser)
    end

    it "keeps a passed-over blob that another attachment still uses" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(ActiveStorage::Blob.exists?(loser.id)).to be(true)
    end

    it "leaves the other show's cover art attached" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(parent.reload.cover_art.blob).to eq(loser)
    end

    it "still drops the candidate attachment" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(show.reload.cover_art_candidates.count).to eq(0)
    end
  end

  describe "zoom" do
    before do
      allow(AlbumCoverService).to receive(:call)
      allow_any_instance_of(Track).to receive(:apply_id3_tags) # rubocop:disable RSpec/AnyInstance
    end

    it "attaches a processed copy rather than the candidate blob" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 25)
      expect(show.reload.cover_art.blob).not_to eq(winner)
    end

    it "produces a 1024x1024 jpeg" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 25)
      Tempfile.create([ "zoomed", ".jpg" ], binmode: true) do |file|
        file.write(show.reload.cover_art.download)
        file.flush
        expect(MiniMagick::Image.open(file.path).dimensions).to eq([ 1024, 1024 ])
      end
    end

    it "crops in rather than copying the source pixels" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 50)
      expect(show.reload.cover_art.download).not_to eq(winner.download)
    end

    it "keeps the zoom source blob, which the show no longer references" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 25)
      expect(ActiveStorage::Blob.exists?(winner.id)).to be(true)
    end
  end

  describe "ID3 re-embedding" do
    let!(:track) { create(:track, show:, position: 1, songs: [ create(:song) ]) }
    let!(:other_track) { create(:track, show:, position: 2, songs: [ create(:song) ]) }

    before { allow(AlbumCoverService).to receive(:call) }

    it "calls apply_id3_tags once per track" do
      calls = []
      allow_any_instance_of(Track).to receive(:apply_id3_tags) { |t| calls << t.id } # rubocop:disable RSpec/AnyInstance
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(calls).to contain_exactly(track.id, other_track.id)
    end

    it "records a failed track and carries on" do
      allow_any_instance_of(Track).to receive(:apply_id3_tags) do |t| # rubocop:disable RSpec/AnyInstance
        raise "mp3info blew up" if t.id == track.id
      end
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(admin_job.reload.payload["failed_tracks"])
        .to eq([ { "track_id" => track.id, "title" => track.title,
                   "error" => "mp3info blew up" } ])
    end

    it "still completes the job when a track fails" do
      allow_any_instance_of(Track).to receive(:apply_id3_tags) do |t| # rubocop:disable RSpec/AnyInstance
        raise "mp3info blew up" if t.id == track.id
      end
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(admin_job.reload.status).to eq("done")
    end

    it "still applies the cover art when a track fails" do
      allow_any_instance_of(Track).to receive(:apply_id3_tags) do |t| # rubocop:disable RSpec/AnyInstance
        raise "mp3info blew up" if t.id == track.id
      end
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(show.reload.cover_art.blob).to eq(winner)
    end

    it "reports progress as tracks complete" do
      progress = []
      allow_any_instance_of(Track).to receive(:apply_id3_tags) # rubocop:disable RSpec/AnyInstance
      allow(admin_job).to receive(:update!).and_wrap_original do |method, attrs|
        progress << attrs[:progress] if attrs[:progress]
        method.call(attrs)
      end
      allow(AdminJob).to receive(:find).with(admin_job.id).and_return(admin_job)
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(progress).to eq([ 10, 20, 50, 80, 100 ])
    end
  end

  describe "propagation to child shows" do
    let!(:child) { create(:show, date: "2024-07-20", cover_art_parent_show_id: show.id) }

    before do
      allow(AlbumCoverService).to receive(:call)
      allow_any_instance_of(Track).to receive(:apply_id3_tags) # rubocop:disable RSpec/AnyInstance
    end

    it "gives the child the same blob" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(child.reload.cover_art.blob).to eq(winner)
    end

    it "composites an album cover for the child too" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(AlbumCoverService).to have_received(:call).with(child)
    end

    it "never reaches the billed image service" do
      allow(CoverArtImageService).to receive(:call)
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(CoverArtImageService).not_to have_received(:call)
    end
  end

  # The real pipeline, no stubs: this is the example that would catch an orphaned
  # variant record, since Id3TagService downloads the album_cover :id3 variant and
  # embeds it into an actual MP3.
  describe "end to end with real image and ID3 processing" do
    let(:mp3_path) { Rails.root.join("tmp/select_cover_art_spec.mp3") }
    let!(:track) { create(:track, show:, position: 1, songs: [ create(:song) ]) }

    before do
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi",
        "-i", "sine=frequency=440:duration=5", "-b:a", "128k", mp3_path.to_s,
        exception: true
      )
      track.mp3_audio.attach(
        io: File.open(mp3_path), filename: "track.mp3", content_type: "audio/mpeg"
      )
      track.update!(audio_status: "complete")
    end

    after { FileUtils.rm_f(mp3_path) }

    it "leaves the show with a usable :id3 variant" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      show.reload
      expect(show.album_cover.variant(:id3).processed.key).to be_present
    end

    it "produces an :id3 variant within 600px" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      variant = show.reload.album_cover.variant(:id3).processed
      Tempfile.create([ "id3", ".jpg" ], binmode: true) do |file|
        file.write(variant.download)
        file.flush
        image = MiniMagick::Image.open(file.path)
        expect([ image.width, image.height ].max).to be <= 600
      end
    end

    # Asserted on the state the job left behind, with no variant processing of its
    # own: calling .processed here would regenerate a missing variant and hide the
    # very orphan this is looking for.
    it "leaves no orphaned variant record behind" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      orphans = ActiveStorage::VariantRecord.left_joins(:image_attachment)
                                            .where(active_storage_attachments: { id: nil })
      expect(orphans).to be_empty
    end

    it "leaves every variant record pointing at a blob that still exists" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      variant_blob_ids = ActiveStorage::VariantRecord.pluck(:blob_id).uniq
      expect(ActiveStorage::Blob.where(id: variant_blob_ids).count)
        .to eq(variant_blob_ids.size)
    end

    it "embeds album art into the track's audio" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(Id3AlbumArtChecker.call(track.reload)).to eq(:present)
    end

    it "can still re-embed art after selection, proving the variant survived" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect { track.reload.apply_id3_tags }.not_to raise_error
      expect(Id3AlbumArtChecker.call(track.reload)).to eq(:present)
    end

    it "records no ID3 failures" do
      described_class.new.perform(show.id, admin_job.id, winner.key, 0)
      expect(admin_job.reload.payload["failed_tracks"]).to eq([])
    end
  end
end
