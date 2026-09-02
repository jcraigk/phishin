require "rails_helper"

RSpec.describe Admin::PnetTagCheckJob do
  let(:show) { create(:show, date: "2024-07-19") }
  let(:track) { create(:track, show:, title: "Harry Hood", position: 1) }
  let(:admin_job) { create(:admin_job, kind: "pnet_tag_check", show:) }
  let(:chart_service) do
    instance_double(
      TeaseChartSyncService,
      call: nil,
      proposed_rows: [ { track:, note: "Norwegian Wood by The Beatles" } ],
      unmatched: [ { date: "2024-07-19", song: "Ghost", note: "Manteca", reason: "no track matched" } ]
    )
  end
  let(:notes_service) do
    instance_double(
      TeaseSyncService,
      call: nil,
      proposed_rows: [ { track:, note: "Fuego" } ],
      unconfirmed: [ "2024-07-19/harry-hood - Kashmir by Led Zeppelin" ],
      unmatched: []
    )
  end

  before do
    allow(TeaseChartSyncService).to receive(:new).and_return(chart_service)
    allow(TeaseSyncService).to receive(:new).and_return(notes_service)
  end

  it "runs both sources as dry runs scoped to the show" do
    described_class.new.perform(show.id, admin_job.id)

    expect(TeaseChartSyncService).to have_received(:new)
      .with(start_date: "2024-07-19", end_date: "2024-07-19")
    expect(TeaseSyncService).to have_received(:new).with(date: "2024-07-19")
    expect(chart_service).to have_received(:call)
    expect(notes_service).to have_received(:call)
  end

  it "writes a textual report to the job payload" do
    described_class.new.perform(show.id, admin_job.id)

    report = admin_job.reload.payload["report"]
    expect(report).to include("Norwegian Wood by The Beatles")
    expect(report).to include("Fuego")
    expect(report).to include("Kashmir by Led Zeppelin")
    expect(report).to include("Ghost: Manteca (no track matched)")
  end

  it "completes the admin job" do
    described_class.new.perform(show.id, admin_job.id)
    expect(admin_job.reload.status).to eq("done")
  end

  it "fails the admin job when a source raises" do
    allow(chart_service).to receive(:call).and_raise(StandardError, "chart down")
    expect { described_class.new.perform(show.id, admin_job.id) }
      .to raise_error(StandardError, "chart down")
    expect(admin_job.reload.status).to eq("failed")
  end
end
