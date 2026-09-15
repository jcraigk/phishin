require "rails_helper"

RSpec.describe Admin::RecomputeGapsJob do
  let(:show) { create(:show, date: "2024-07-19") }
  let(:admin_job) { create(:admin_job, kind: "recompute_gaps", show:) }

  it "recomputes gaps for the show including previous occurrences" do
    allow(GapService).to receive(:call)
    described_class.new.perform(show.id, admin_job.id)
    expect(GapService).to have_received(:call).with(show, update_previous: true)
  end

  it "completes the admin job" do
    allow(GapService).to receive(:call)
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.status).to eq("done")
  end

  it "fills in the gap for a repeated song" do
    song = create(:song, title: "Ghost")
    earlier = create(:show, date: "2024-07-01")
    create(:track, show: earlier, position: 1, title: "Ghost", set: "1", songs: [ song ])
    create(:track, show:, position: 1, title: "Ghost", set: "1", songs: [ song ])

    described_class.new.perform(show.id, admin_job.id)
    expect(show.tracks.first.songs_tracks.first)
      .to have_attributes(
        previous_performance_gap: 1, previous_performance_slug: "#{earlier.date}/ghost"
      )
  end

  it "fails the admin job when the service raises" do
    allow(GapService).to receive(:call).and_raise(StandardError, "gap boom")
    expect { described_class.new.perform(show.id, admin_job.id) }
      .to raise_error(StandardError, "gap boom")
    expect(admin_job.reload).to have_attributes(status: "failed", message: "gap boom")
  end
end
