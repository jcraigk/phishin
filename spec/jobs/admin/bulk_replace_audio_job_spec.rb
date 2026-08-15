require "rails_helper"

RSpec.describe Admin::BulkReplaceAudioJob do
  let(:show) { create(:show, date: "2024-07-19") }
  let!(:with_audio) do
    create(:track, show:, position: 1, title: "Ghost", slug: "ghost")
  end
  let!(:without_audio) do
    create(:track, show:, position: 2, title: "Bathtub Gin", slug: "gin", audio_status: "missing")
  end
  let(:admin_job) { create(:admin_job, kind: "bulk_replace_audio", show:) }
  let(:old_source) { Rails.root.join("tmp/spec/audio_30s.mp3") }
  let(:new_source) { Rails.root.join("tmp/spec/audio_20s_880.mp3") }

  before do
    render_tone(old_source, frequency: 440, duration: 30)
    render_tone(new_source, frequency: 880, duration: 20)
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
    FileUtils.rm_rf(TrackAudioReplacer::BACKUP_DIR)
    attach_old_audio(with_audio)
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

  def new_blob(filename)
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(new_source), filename:, content_type: "audio/mpeg"
    )
  end

  def attach_old_audio(track)
    track.mp3_audio.attach(
      io: File.open(old_source), filename: "old.mp3", content_type: "audio/mpeg"
    )
    track.update!(audio_status: "complete")
  end

  def run_with(assignments)
    described_class.new.perform(show.id, admin_job.id, assignments)
  end

  describe "a mixed replace and fill batch" do
    let(:assignments) do
      [
        { "signed_id" => new_blob("01 Ghost.mp3").signed_id, "track_id" => with_audio.id },
        { "signed_id" => new_blob("02 Gin.mp3").signed_id, "track_id" => without_audio.id }
      ]
    end

    it "completes the admin job" do
      run_with(assignments)
      expect(admin_job.reload.status).to eq("done")
    end

    it "replaces the audio on the track that had some" do
      old_key = with_audio.mp3_audio.blob.key
      run_with(assignments)
      expect(with_audio.reload.mp3_audio.blob.key).not_to eq(old_key)
    end

    it "gives the replaced track the new bytes" do
      run_with(assignments)
      expect(with_audio.reload.mp3_audio.blob.download).to eq(File.binread(new_source))
    end

    it "fills the track that had no audio" do
      run_with(assignments)
      expect(without_audio.reload.mp3_audio.attached?).to be(true)
    end

    it "marks the filled track complete" do
      run_with(assignments)
      expect(without_audio.reload.audio_status).to eq("complete")
    end

    it "backs up the original of the replaced track" do
      old_key = with_audio.mp3_audio.blob.key
      run_with(assignments)
      backup = TrackAudioReplacer::BACKUP_DIR.join("2024-07-19_ghost_#{old_key}.mp3")
      expect(File.binread(backup)).to eq(File.binread(old_source))
    end

    it "writes exactly one backup, for the replace and not the fill" do
      run_with(assignments)
      expect(Dir.glob(TrackAudioReplacer::BACKUP_DIR.join("*.mp3")).size).to eq(1)
    end

    it "reports the replaced track on the payload" do
      run_with(assignments)
      expect(admin_job.reload.payload["replaced"].map { |r| r["track_id"] })
        .to eq([ with_audio.id ])
    end

    it "reports the filled track on the payload" do
      run_with(assignments)
      expect(admin_job.reload.payload["filled"].map { |r| r["track_id"] })
        .to eq([ without_audio.id ])
    end

    it "records no failures" do
      run_with(assignments)
      expect(admin_job.reload.payload["failed"]).to be_empty
    end

    it "summarizes the batch in the job message" do
      run_with(assignments)
      expect(admin_job.reload.message).to eq("Replaced 1, filled 1 of 2 files")
    end

    it "brings the show's audio status up with its tracks" do
      run_with(assignments)
      expect(show.reload.audio_status).to eq("complete")
    end
  end

  # The whole point of a bulk run: an admin dropping forty files must not lose
  # thirty-nine of them because one blob went missing.
  describe "one assignment failing" do
    let(:assignments) do
      [
        { "signed_id" => "nonsense", "track_id" => with_audio.id },
        { "signed_id" => new_blob("02 Gin.mp3").signed_id, "track_id" => without_audio.id }
      ]
    end

    it "does not raise" do
      expect { run_with(assignments) }.not_to raise_error
    end

    it "still marks the job done" do
      run_with(assignments)
      expect(admin_job.reload.status).to eq("done")
    end

    it "still applies the assignment that worked" do
      run_with(assignments)
      expect(without_audio.reload.mp3_audio.attached?).to be(true)
    end

    it "leaves the failed track's original audio in place" do
      old_key = with_audio.mp3_audio.blob.key
      run_with(assignments)
      expect(with_audio.reload.mp3_audio.blob.key).to eq(old_key)
    end

    it "records the failure on the payload" do
      run_with(assignments)
      failure = admin_job.reload.payload["failed"].first
      expect(failure["track_id"]).to eq(with_audio.id)
    end

    it "counts the failure in the job message" do
      run_with(assignments)
      expect(admin_job.reload.message).to eq("Replaced 0, filled 1, 1 failed of 2 files")
    end
  end

  describe "every assignment failing" do
    let(:assignments) do
      [
        { "signed_id" => "nonsense", "track_id" => with_audio.id },
        { "signed_id" => "garbage", "track_id" => without_audio.id }
      ]
    end

    it "fails the admin job" do
      expect { run_with(assignments) }.to raise_error(/All 2 assignments failed/)
      expect(admin_job.reload.status).to eq("failed")
    end
  end

  # process_mp3_audio's ID3 rewrite replaces the attachment, and replacement
  # purges the blob it displaced. Sharing one upload across two tracks would
  # destroy it under the second track mid-batch.
  it "leaves each uploaded blob intact after the batch" do
    allow(Id3TagService).to receive(:call).and_call_original
    blobs = [ new_blob("01 Ghost.mp3"), new_blob("02 Gin.mp3") ]
    assignments = [
      { "signed_id" => blobs.first.signed_id, "track_id" => with_audio.id },
      { "signed_id" => blobs.second.signed_id, "track_id" => without_audio.id }
    ]
    Sidekiq::Testing.inline! { run_with(assignments) }
    expect(blobs.map { |b| ActiveStorage::Blob.exists?(b.id) }).to eq([ true, true ])
  end
end
