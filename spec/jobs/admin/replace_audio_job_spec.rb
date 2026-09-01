require "rails_helper"

RSpec.describe Admin::ReplaceAudioJob do
  let(:show) { create(:show, date: "2024-07-19") }
  let(:song) { create(:song, title: "Ghost") }
  let!(:track) do
    create(:track, show:, position: 1, title: "Ghost", songs: [ song ], slug: "target")
  end
  let(:admin_job) { create(:admin_job, kind: "replace_audio", track:, show:) }
  let(:old_source) { Rails.root.join("tmp/spec/audio_30s.mp3") }
  let(:new_source) { Rails.root.join("tmp/spec/audio_20s_880.mp3") }

  before do
    render_tone(old_source, frequency: 440, duration: 30)
    render_tone(new_source, frequency: 880, duration: 20)
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
    FileUtils.rm_rf(AudioBackup::DIR)
  end

  def render_tone(path, frequency:, duration:)
    FileUtils.mkdir_p(path.dirname)
    return if File.exist?(path)
    system(
      "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
      "sine=frequency=#{frequency}:duration=#{duration}", "-b:a", "128k", path.to_s,
      exception: true
    )
  end

  def new_blob
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(new_source), filename: "new.mp3", content_type: "audio/mpeg"
    )
  end

  def attach_old_audio
    track.mp3_audio.attach(
      io: File.open(old_source), filename: "old.mp3", content_type: "audio/mpeg"
    )
    track.update!(audio_status: "complete")
  end

  describe "a track with existing audio" do
    before { attach_old_audio }

    it "completes the admin job" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(admin_job.reload.status).to eq("done")
    end

    it "backs up the original under the show date, slug, operation and time" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      backup = admin_job.reload.payload["backup_path"]
      expect(File.basename(backup))
        .to match(/\A2024-07-19_target_replace_audio_\d{8}-\d{6}\.mp3\z/)
      expect(File.exist?(backup)).to be(true)
    end

    # The point of the backup is recovering the file the replace displaced, so it
    # has to hold the bytes that were there before, not the ones that replaced them.
    it "writes the original bytes to the backup, not the replacement" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      backup = admin_job.reload.payload["backup_path"]
      expect(File.binread(backup)).to eq(File.binread(old_source))
    end

    it "records the backup path on the job" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      backup = admin_job.reload.payload["backup_path"]
      expect(backup).to start_with(AudioBackup::DIR.to_s)
    end

    it "swaps the attachment off the original blob" do
      old_key = track.mp3_audio.blob.key
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(track.reload.mp3_audio.blob.key).not_to eq(old_key)
    end

    it "attaches audio holding the replacement bytes" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(track.reload.mp3_audio.blob.download).to eq(File.binread(new_source))
    end

    it "updates the duration to the replacement's" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(track.reload.duration).to be_within(500).of(20_000)
    end

    it "keeps the track's other attributes intact" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(track.reload).to have_attributes(
        title: "Ghost", position: 1, slug: "target", set: track.set,
        audio_status: "complete", songs: [ song ]
      )
    end

    # process_mp3_audio replaces the attachment to rewrite ID3 tags, and replacing
    # an attachment purges the blob it replaced. Attaching the uploaded blob itself
    # rather than a copy of its bytes would destroy the upload mid-job.
    #
    # Two things have to be real for that to be observable: the ID3 rewrite that
    # does the replacing, and the purge itself, which ActiveStorage defers with
    # purge_later. Under the suite's fake Sidekiq queue the purge is only enqueued,
    # so a stubbed Id3TagService or a fake queue both let the bug pass unnoticed.
    it "leaves the uploaded blob intact for other references" do
      allow(Id3TagService).to receive(:call).and_call_original
      blob = new_blob
      Sidekiq::Testing.inline! do
        described_class.new.perform(track.id, admin_job.id, blob.signed_id)
      end
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
    end
  end

  # The fill case a bulk upsert hits on most tracks: no audio yet, so nothing to
  # back up. The factory defaults audio_status to "complete", so this starts from
  # "missing" to match a real audioless track and to make the status assertion
  # test the code rather than the factory.
  describe "a track with no existing audio" do
    before { track.update!(audio_status: "missing") }

    it "does not raise" do
      expect { described_class.new.perform(track.id, admin_job.id, new_blob.signed_id) }
        .not_to raise_error
    end

    it "attaches the audio" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(track.reload.mp3_audio.attached?).to be(true)
    end

    it "marks the audio complete" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(track.reload.audio_status).to eq("complete")
    end

    it "sets the duration" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(track.reload.duration).to be_within(500).of(20_000)
    end

    it "writes no backup" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(Dir.glob(AudioBackup::DIR.join("*.mp3"))).to be_empty
    end

    it "records no backup path on the job" do
      described_class.new.perform(track.id, admin_job.id, new_blob.signed_id)
      expect(admin_job.reload.payload).not_to have_key("backup_path")
    end
  end

  describe "failures" do
    it "fails the admin job on an unknown signed id" do
      expect { described_class.new.perform(track.id, admin_job.id, "nonsense") }
        .to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
      expect(admin_job.reload.status).to eq("failed")
    end

    it "leaves the existing audio in place when the signed id is bad" do
      attach_old_audio
      old_key = track.mp3_audio.blob.key
      expect { described_class.new.perform(track.id, admin_job.id, "nonsense") }
        .to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
      expect(track.reload.mp3_audio.blob.key).to eq(old_key)
    end
  end
end
