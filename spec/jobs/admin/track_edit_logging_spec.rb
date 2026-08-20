require "rails_helper"

# Every audio-affecting operation leaves a record. Trim and boundary shift have
# their own timestamp specs; this covers the remaining four and the one rule they
# share - the log is written when the operation is APPLIED, never on a preview.
RSpec.describe TrackEdit do
  let(:show) { create(:show, date: "2024-07-19", published: false) }
  let(:tag) { create(:tag, name: "Tease") }

  before do
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
  end

  def tone(seconds, frequency: 440)
    path = Rails.root.join("tmp/spec/edit_log_#{frequency}_#{seconds}s.mp3")
    FileUtils.mkdir_p(path.dirname)
    unless File.exist?(path)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=#{frequency}:duration=#{seconds}", "-b:a", "128k",
        path.to_s, exception: true
      )
    end
    path
  end

  def attach(track, seconds, frequency: 440)
    track.mp3_audio.attach(
      io: File.open(tone(seconds, frequency:)), filename: "audio.mp3",
      content_type: "audio/mpeg"
    )
    track.update!(audio_status: "complete")
  end

  describe Admin::ReplaceAudioJob do
    let!(:track) { create(:track, show:, position: 1, title: "Ghost", slug: "ghost") }
    let(:admin_job) { create(:admin_job, kind: "replace_audio", track:, show:) }
    let!(:track_tag) do
      create(:track_tag, track:, tag:, starts_at_second: 5, ends_at_second: 8)
    end

    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: File.open(tone(20, frequency: 880)), filename: "new.mp3",
        content_type: "audio/mpeg"
      )
    end

    before { attach(track, 30) }

    def run! = described_class.new.perform(track.id, admin_job.id, blob.signed_id)

    it "writes a TrackEdit" do
      expect { run! }.to change { TrackEdit.where(operation: "replace_audio").count }.by(1)
    end

    # No delta exists. The new file is a different recording of the same music at
    # best, and nothing in it says where the old file's five-second mark went.
    it "records no delta" do
      run!
      expect(TrackEdit.last.payload["delta_s"]).to be_nil
    end

    it "orphans the timestamped tag" do
      run!
      expect(track_tag.reload.orphan_reason).to eq("audio_replaced")
    end

    it "keeps the orphaned tag's original numbers" do
      run!
      expect([ track_tag.reload.starts_at_second, track_tag.reload.ends_at_second ])
        .to eq([ 5, 8 ])
    end

    it "never deletes it" do
      run!
      expect(TrackTag.exists?(track_tag.id)).to be(true)
    end

    it "records the orphan in the payload" do
      run!
      expect(TrackEdit.last.payload["orphaned"]).to include(
        hash_including("type" => "TrackTag", "reason" => "audio_replaced")
      )
    end

    it "records the backup path" do
      run!
      expect(TrackEdit.last.payload["backup_path"]).to be_present
    end

    # The duration the ROW claimed before the edit, not a fresh probe of the file
    # being displaced. It is read off the track because that is the number the
    # rest of the app was working from, and a history that disagreed with it
    # would be describing an edit nobody made.
    it "records the duration it replaced" do
      track.update!(duration: 30_000)
      run!
      expect(TrackEdit.last.payload["duration_before_s"]).to eq(30.0)
    end
  end

  describe Admin::BulkReplaceAudioJob do
    let!(:track) { create(:track, show:, position: 1, title: "Ghost", slug: "ghost") }
    let(:admin_job) { create(:admin_job, kind: "bulk_replace_audio", show:) }
    let!(:track_tag) { create(:track_tag, track:, tag:, starts_at_second: 5) }

    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: File.open(tone(20, frequency: 880)), filename: "new.mp3",
        content_type: "audio/mpeg"
      )
    end

    before { attach(track, 30) }

    def run!
      described_class.new.perform(
        show.id, admin_job.id,
        [ { "track_id" => track.id, "signed_id" => blob.signed_id } ]
      )
    end

    it "writes a TrackEdit under its own operation name" do
      expect { run! }
        .to change { TrackEdit.where(operation: "bulk_replace_audio").count }.by(1)
    end

    it "orphans the timestamped tag too" do
      run!
      expect(track_tag.reload.orphan_reason).to eq("audio_replaced")
    end
  end
end
