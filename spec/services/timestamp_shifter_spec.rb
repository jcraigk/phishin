require "rails_helper"

RSpec.describe TimestampShifter do
  subject(:result) do
    described_class.call(track:, delta_s:, new_duration_s:, reason:)
  end

  let(:show) { create(:show, date: "1992-07-11") }
  let(:track) { create(:track, show:, title: "The Landlady", position: 1) }
  let(:tag) { create(:tag, name: "Tease") }
  let(:delta_s) { -3.0 }
  let(:new_duration_s) { 300.0 }
  let(:reason) { "trim" }

  def timestamped_tag(starts:, ends: nil)
    create(:track_tag, track:, tag:, starts_at_second: starts, ends_at_second: ends)
  end

  describe "a window wholly inside the new audio" do
    let!(:track_tag) { timestamped_tag(starts: 66, ends: 80) }

    it "shifts it by the delta" do
      result
      expect(track_tag.reload.starts_at_second).to eq(63)
    end

    it "shifts its end by the delta too" do
      result
      expect(track_tag.reload.ends_at_second).to eq(77)
    end

    it "leaves it unflagged" do
      result
      expect(track_tag.reload.orphaned_at).to be_nil
    end

    it "reports the move with the shape TrackEdit records" do
      expect(result[:shifted]).to contain_exactly(
        { "type" => "TrackTag", "id" => track_tag.id, "from" => 66, "to" => 63 }
      )
    end
  end

  describe "a window whose start falls past the new end" do
    let!(:track_tag) { timestamped_tag(starts: 400, ends: 420) }

    it "orphans it" do
      result
      expect(track_tag.reload.orphan_reason).to eq("past_new_end")
    end

    it "stamps orphaned_at" do
      result
      expect(track_tag.reload.orphaned_at).to be_present
    end

    it "KEEPS its original start" do
      result
      expect(track_tag.reload.starts_at_second).to eq(400)
    end

    it "KEEPS its original end" do
      result
      expect(track_tag.reload.ends_at_second).to eq(420)
    end

    it "never deletes the row" do
      result
      expect(TrackTag.exists?(track_tag.id)).to be(true)
    end

    it "reports it with the shape TrackEdit records" do
      expect(result[:orphaned]).to contain_exactly(
        { "type" => "TrackTag", "id" => track_tag.id, "at" => 400,
          "reason" => "past_new_end" }
      )
    end
  end

  describe "a window whose start falls before 0" do
    let(:delta_s) { -30.0 }
    let!(:track_tag) { timestamped_tag(starts: 10, ends: 90) }

    it "orphans it" do
      result
      expect(track_tag.reload.orphan_reason).to eq("before_new_start")
    end

    it "KEEPS its original numbers" do
      result
      expect(track_tag.reload.starts_at_second).to eq(10)
    end

    it "is not reported as shifted" do
      expect(result[:shifted]).to be_empty
    end
  end

  describe "a window that merely overlaps the new end" do
    let!(:track_tag) { timestamped_tag(starts: 200, ends: 400) }

    it "shifts the start that survives" do
      result
      expect(track_tag.reload.starts_at_second).to eq(197)
    end

    it "clamps the end to the new duration" do
      result
      expect(track_tag.reload.ends_at_second).to eq(300)
    end

    it "is not orphaned - part of it still describes real audio" do
      result
      expect(track_tag.reload.orphaned_at).to be_nil
    end

    it "is reported as clamped rather than shifted" do
      expect(result[:clamped]).to contain_exactly(
        { "type" => "TrackTag", "id" => track_tag.id, "from" => 200, "to" => 197 }
      )
    end
  end

  describe "a nil delta - wholesale audio replacement" do
    let(:delta_s) { nil }
    let(:new_duration_s) { 500.0 }
    let(:reason) { "replace_audio" }
    let!(:inside) { timestamped_tag(starts: 66, ends: 80) }
    let!(:later) { timestamped_tag(starts: 400) }

    before { track.update!(jam_starts_at_second: 120) }

    it "orphans every timestamped tag, even ones inside the new duration" do
      result
      expect(TrackTag.where.not(orphaned_at: nil).pluck(:id))
        .to contain_exactly(inside.id, later.id)
    end

    it "gives them a reason that says why the offsets are unmappable" do
      result
      expect(inside.reload.orphan_reason).to eq("audio_replaced")
    end

    it "keeps their original numbers" do
      result
      expect(inside.reload.starts_at_second).to eq(66)
    end

    it "orphans the jam start too" do
      expect(result[:orphaned]).to include(
        hash_including("type" => "Track", "at" => 120, "reason" => "audio_replaced")
      )
    end
  end

  describe "untimestamped tags" do
    let!(:whole_recording) { create(:track_tag, track:, tag:) }

    it "leaves them alone - they describe the recording, not a moment in it" do
      result
      expect(whole_recording.reload.orphaned_at).to be_nil
    end

    it "does not report them" do
      expect(result[:shifted]).to be_empty
    end
  end

  describe "jam_starts_at_second" do
    before { track.update!(jam_starts_at_second: 120) }

    it "moves with the audio" do
      result
      expect(track.reload.jam_starts_at_second).to eq(117)
    end

    it "reports the move" do
      expect(result[:shifted]).to contain_exactly(
        { "type" => "Track", "id" => track.id, "from" => 120, "to" => 117 }
      )
    end

    context "when it lands past the new end" do
      let(:new_duration_s) { 100.0 }

      it "is cleared rather than left pointing at the wrong moment" do
        result
        expect(track.reload.jam_starts_at_second).to be_nil
      end

      it "records the original value so it is recoverable from the payload" do
        expect(result[:orphaned]).to contain_exactly(
          { "type" => "Track", "id" => track.id, "at" => 120,
            "reason" => "past_new_end", "field" => "jam_starts_at_second" }
        )
      end
    end
  end

  describe "PlaylistTrack excerpts" do
    let(:playlist) { create(:playlist) }

    def excerpt(starts:, ends:)
      create(:playlist_track, playlist:, track:,
             starts_at_second: starts, ends_at_second: ends)
    end

    it "shifts an excerpt that lands inside the new audio" do
      entry = excerpt(starts: 66, ends: 80)
      result
      expect(entry.reload.starts_at_second).to eq(63)
    end

    it "clamps rather than orphans one that runs past the new end" do
      entry = excerpt(starts: 200, ends: 400)
      result
      expect(entry.reload.ends_at_second).to eq(300)
    end

    it "clamps an excerpt that starts past the new end into range" do
      entry = excerpt(starts: 400, ends: 450)
      result
      expect(entry.reload.starts_at_second).to eq(300)
    end

    it "reports it as clamped, never orphaned" do
      excerpt(starts: 400, ends: 450)
      expect(result[:orphaned]).to be_empty
    end

    it "clamps a negative start to the top of the track" do
      entry = excerpt(starts: 10, ends: 90)
      described_class.call(track:, delta_s: -30.0, new_duration_s:, reason:)
      expect(entry.reload.starts_at_second).to eq(0)
    end

    it "leaves an unbounded whole-track entry alone" do
      entry = excerpt(starts: nil, ends: nil)
      result
      expect(entry.reload.starts_at_second).to be_nil
    end

    it "does not report an unbounded entry" do
      excerpt(starts: nil, ends: nil)
      expect(result[:clamped]).to be_empty
    end

    context "with a nil delta" do
      let(:delta_s) { nil }

      it "still never orphans a user's excerpt" do
        excerpt(starts: 66, ends: 80)
        expect(result[:orphaned]).to be_empty
      end
    end
  end

  describe "a tail trim, which moves nothing but shortens the audio" do
    let(:delta_s) { 0.0 }
    let(:new_duration_s) { 100.0 }
    let!(:survivor) { timestamped_tag(starts: 66, ends: 80) }
    let!(:cut_away) { timestamped_tag(starts: 400) }

    it "leaves the surviving tag where it is" do
      result
      expect(survivor.reload.starts_at_second).to eq(66)
    end

    it "orphans the one that no longer has audio under it" do
      result
      expect(cut_away.reload.orphan_reason).to eq("past_new_end")
    end
  end

  describe "a fractional delta" do
    let(:delta_s) { -2.6 }

    before { track.update!(jam_starts_at_second: 66) }

    it "rounds the tag and the jam start the same way" do
      tag_row = timestamped_tag(starts: 66)
      result
      expect([ tag_row.reload.starts_at_second, track.reload.jam_starts_at_second ])
        .to eq([ 63, 63 ])
    end
  end
end
