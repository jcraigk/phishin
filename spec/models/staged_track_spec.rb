require "rails_helper"

RSpec.describe StagedTrack do
  let(:show) { create(:show, date: "2024-07-19") }

  it "requires the end to come after the start by at least a second" do
    track = build(:staged_track, show:, start_s: 10.0, end_s: 10.5)
    expect(track).not_to be_valid
    expect(track.errors[:end_s]).to be_present
  end

  it "rejects an unknown set" do
    expect(build(:staged_track, show:, set: "X")).not_to be_valid
  end

  it "walks to its neighbors by position" do
    a = create(:staged_track, show:, position: 1, start_s: 0, end_s: 10)
    b = create(:staged_track, show:, position: 2, start_s: 10, end_s: 20)
    expect(a.next_track).to eq(b)
    expect(b.previous_track).to eq(a)
    expect(a.previous_track).to be_nil
  end

  # Positions carry a unique index scoped to the show, so a renumber that assigns
  # final positions row by row collides with a row that has not moved yet.
  describe ".renumber!" do
    it "orders rows by start time and closes gaps" do
      create(:staged_track, show:, position: 5, start_s: 20, end_s: 30)
      create(:staged_track, show:, position: 9, start_s: 0, end_s: 10)
      create(:staged_track, show:, position: 7, start_s: 10, end_s: 20)
      described_class.renumber!(show)
      expect(show.staged_tracks.order(:position).pluck(:position, :start_s).map { |p, s| [ p, s.to_f ] })
        .to eq([ [ 1, 0.0 ], [ 2, 10.0 ], [ 3, 20.0 ] ])
    end
  end

  it "marks a show as staging while it has sources" do
    expect(show.staging?).to be(false)
    create(:staged_source, show:)
    expect(show.reload.staging?).to be(true)
  end
end
