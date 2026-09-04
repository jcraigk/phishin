require "rails_helper"

RSpec.describe AlbumZipJob do
  let(:show) { create(:show, album_zip_requested_at: 1.minute.ago) }
  let(:job) { described_class.new }

  context "when the disk is low on space" do
    before { allow(job).to receive(:free_disk_bytes).and_return(1.gigabyte) }

    it "reschedules itself instead of building" do
      allow(described_class).to receive(:perform_in)
      job.perform(show.id)
      expect(described_class)
        .to have_received(:perform_in).with(described_class::RETRY_DELAY, show.id)
    end

    it "does not attach a zip" do
      allow(described_class).to receive(:perform_in)
      job.perform(show.id)
      expect(show.reload.album_zip.attached?).to be(false)
    end

    it "keeps the request timestamp so the show stays queued" do
      allow(described_class).to receive(:perform_in)
      job.perform(show.id)
      expect(show.reload.album_zip_requested_at).to be_present
    end
  end

  describe "the stale tempfile sweep" do
    let(:stale) { File.join(Dir.tmpdir, "album-zip-stale-spec.zip") }
    let(:fresh) { File.join(Dir.tmpdir, "album-zip-fresh-spec.zip") }

    before do
      allow(job).to receive(:free_disk_bytes).and_return(1.gigabyte)
      allow(described_class).to receive(:perform_in)
    end

    after { FileUtils.rm_f([ stale, fresh ]) }

    it "deletes tempfiles older than the stale age" do
      File.write(stale, "x")
      FileUtils.touch(stale, mtime: 2.hours.ago.to_time)
      job.perform(show.id)
      expect(File.exist?(stale)).to be(false)
    end

    it "keeps recent tempfiles" do
      File.write(fresh, "x")
      job.perform(show.id)
      expect(File.exist?(fresh)).to be(true)
    end
  end

  describe "#free_disk_bytes" do
    it "reports a positive byte count" do
      expect(job.send(:free_disk_bytes)).to be > 0
    end
  end
end
