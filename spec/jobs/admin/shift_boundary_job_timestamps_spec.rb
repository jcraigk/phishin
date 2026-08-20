require "rails_helper"

# The subtle half of the defect this phase fixes. A boundary shift moves audio
# ACROSS a boundary, so the two tracks do not share a delta: the first track
# keeps its origin and only changes length, while everything on the second track
# moves by the opposite of the shift. Both sides are pinned here because getting
# the second side's sign backwards is the failure mode that looks right on the
# first track and silently breaks the second.
RSpec.describe Admin::ShiftBoundaryJob do
  let(:show) { create(:show, date: "2024-07-19", published: false) }
  let!(:first) { create(:track, show:, position: 1, title: "Ghost", slug: "ghost") }
  let!(:second) { create(:track, show:, position: 2, title: "Free", slug: "free") }
  let(:tag) { create(:tag, name: "Tease") }
  let(:admin_job) do
    create(:admin_job, kind: "shift_boundary_apply", track: first, show:)
  end

  before do
    allow(WaveformImageService).to receive(:call)
    allow(Id3TagService).to receive(:call)
    attach(first, 10)
    attach(second, 6)
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

  def edit_for(track)
    TrackEdit.where(track:, operation: "shift_boundary").newest_first.first
  end

  # Two seconds of the second track become the tail of the first.
  describe "shifting the boundary later" do
    let(:delta_s) { 2.0 }

    it "pulls a tag on the second track back by the shift" do
      track_tag = create(:track_tag, track: second, tag:, starts_at_second: 5)
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(track_tag.reload.starts_at_second).to eq(3)
    end

    it "leaves a tag on the first track where it was" do
      track_tag = create(:track_tag, track: first, tag:, starts_at_second: 4)
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(track_tag.reload.starts_at_second).to eq(4)
    end

    it "records a delta of zero on the first track" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(edit_for(first).payload["delta_s"]).to eq(0.0)
    end

    it "records the OPPOSITE delta on the second track" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(edit_for(second).payload["delta_s"]).to eq(-2.0)
    end

    it "records the first track's longer duration" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(edit_for(first).payload["duration_after_s"]).to be_within(0.3).of(12.0)
    end

    it "records the second track's shorter duration" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(edit_for(second).payload["duration_after_s"]).to be_within(0.3).of(4.0)
    end

    it "writes one record per side" do
      expect { described_class.new.perform(first.id, admin_job.id, delta_s, true) }
        .to change { TrackEdit.where(operation: "shift_boundary").count }.by(2)
    end

    it "names which side each record is" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect([ edit_for(first).payload["side"], edit_for(second).payload["side"] ])
        .to eq(%w[first second])
    end

    it "points each record at the other side" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(edit_for(first).payload["paired_track_id"]).to eq(second.id)
    end

    it "records the backup path for each side" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(edit_for(second).payload["backup_path"]).to be_present
    end

    # The second track lost its first two seconds to the track above, so a tag
    # that lived in them describes audio the second track no longer holds. It is
    # not moved onto the first track: reparenting a window across a boundary is a
    # judgment this makes no attempt at, so it is kept and flagged instead.
    it "orphans a tag that fell into the audio handed to the first track" do
      track_tag = create(:track_tag, track: second, tag:, starts_at_second: 1)
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(track_tag.reload.orphan_reason).to eq("before_new_start")
    end

    it "keeps that orphaned tag's original numbers" do
      track_tag = create(:track_tag, track: second, tag:, starts_at_second: 1)
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(track_tag.reload.starts_at_second).to eq(1)
    end
  end

  # Two seconds of the first track become the head of the second.
  describe "shifting the boundary earlier" do
    let(:delta_s) { -2.0 }

    it "pushes a tag on the second track forward by the shift" do
      track_tag = create(:track_tag, track: second, tag:, starts_at_second: 3)
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(track_tag.reload.starts_at_second).to eq(5)
    end

    it "records the opposite delta on the second track" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(edit_for(second).payload["delta_s"]).to eq(2.0)
    end

    it "still records a delta of zero on the first track" do
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(edit_for(first).payload["delta_s"]).to eq(0.0)
    end

    # The first track keeps its origin, so nothing on it moves - but it is two
    # seconds shorter, so a tag in the seconds it gave away now points past its
    # own end.
    it "orphans a tag left past the first track's new end" do
      track_tag = create(:track_tag, track: first, tag:, starts_at_second: 9)
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(track_tag.reload.orphan_reason).to eq("past_new_end")
    end

    it "keeps a tag inside the first track's surviving audio" do
      track_tag = create(:track_tag, track: first, tag:, starts_at_second: 4)
      described_class.new.perform(first.id, admin_job.id, delta_s, true)
      expect(track_tag.reload.starts_at_second).to eq(4)
    end
  end

  describe "a preview" do
    it "moves no timestamp" do
      track_tag = create(:track_tag, track: second, tag:, starts_at_second: 5)
      described_class.new.perform(first.id, admin_job.id, 2.0, false)
      expect(track_tag.reload.starts_at_second).to eq(5)
    end

    it "writes no TrackEdit" do
      expect { described_class.new.perform(first.id, admin_job.id, 2.0, false) }
        .not_to change(TrackEdit, :count)
    end
  end
end
