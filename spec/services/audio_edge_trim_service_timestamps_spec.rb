require "rails_helper"

# The trim half of the defect this phase fixes: a trim used to cut seconds off
# the head of a track and leave every timestamp on it pointing at the audio that
# used to be there.
RSpec.describe AudioEdgeTrimService do
  subject(:result) do
    described_class.call(track, trim_start:, trim_end:, dry_run:, min_cut: 0.5)
  end

  let(:show) { create(:show, date: "1992-07-11") }
  let(:track) { create(:track, show:, title: "The Landlady", position: 1) }
  let(:tag) { create(:tag, name: "Tease") }
  let(:trim_start) { 3.0 }
  let(:trim_end) { 30.0 }
  let(:dry_run) { false }
  let(:source) { Rails.root.join("tmp/spec/audio_30s.mp3") }

  before do
    FileUtils.mkdir_p(source.dirname)
    unless File.exist?(source)
      system(
        "ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i",
        "sine=frequency=440:duration=30", "-b:a", "128k", source.to_s,
        exception: true
      )
    end
    track.mp3_audio.attach(
      io: File.open(source), filename: "audio.mp3", content_type: "audio/mpeg"
    )
    allow(WaveformImageService).to receive(:call)
  end

  describe "a head trim" do
    let!(:track_tag) do
      create(:track_tag, track:, tag:, starts_at_second: 20, ends_at_second: 25)
    end

    it "moves the tag back by the trim amount" do
      result
      expect(track_tag.reload.starts_at_second).to eq(17)
    end

    it "moves the tag's end too" do
      result
      expect(track_tag.reload.ends_at_second).to eq(22)
    end

    it "leaves the tag unorphaned" do
      result
      expect(track_tag.reload.orphaned_at).to be_nil
    end

    it "moves the jam start with it" do
      track.update!(jam_starts_at_second: 20)
      result
      expect(track.reload.jam_starts_at_second).to eq(17)
    end

    it "copies the original audio aside with a stamped filename" do
      backup = result[:backup_path]
      expect(backup).to include("_trim_")
      expect(File.exist?(backup)).to be(true)
    end
  end

  describe "a trim that cuts past the tag" do
    let(:trim_start) { 0.0 }
    let(:trim_end) { 10.0 }
    let!(:track_tag) do
      create(:track_tag, track:, tag:, starts_at_second: 20, ends_at_second: 25)
    end

    it "orphans the tag rather than deleting it" do
      result
      expect(TrackTag.exists?(track_tag.id)).to be(true)
    end

    it "keeps the tag's original start" do
      result
      expect(track_tag.reload.starts_at_second).to eq(20)
    end

    it "keeps the tag's original end" do
      result
      expect(track_tag.reload.ends_at_second).to eq(25)
    end

    it "flags it with a reason" do
      result
      expect(track_tag.reload.orphan_reason).to eq("past_new_end")
    end
  end

  describe "a dry run" do
    let(:dry_run) { true }
    let!(:track_tag) do
      create(:track_tag, track:, tag:, starts_at_second: 20, ends_at_second: 25)
    end

    it "moves nothing" do
      result
      expect(track_tag.reload.starts_at_second).to eq(20)
    end
  end
end
