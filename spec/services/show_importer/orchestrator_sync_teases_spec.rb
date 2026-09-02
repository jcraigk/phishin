require "rails_helper"

RSpec.describe ShowImporter::Orchestrator, "#sync_teases" do
  subject(:sync) { orchestrator.send(:sync_teases) }

  let(:date) { "1995-10-31" }
  let(:show) { create(:show, date:) }
  let(:orchestrator) { described_class.allocate }
  let(:notes_service) { instance_double(TeaseSyncService, call: nil) }
  let(:chart_service) { instance_double(TeaseChartSyncService, call: nil) }

  before do
    allow(orchestrator).to receive(:show).and_return(show)
    allow(TeaseSyncService).to receive(:new).and_return(notes_service)
    allow(TeaseChartSyncService).to receive(:new).and_return(chart_service)
  end

  it "scans the setlist notes for this show with apply enabled" do
    sync

    expect(TeaseSyncService).to have_received(:new).with(date:, apply: true)
    expect(notes_service).to have_received(:call)
  end

  it "checks the tease chart for this show with apply enabled" do
    sync

    expect(TeaseChartSyncService).to have_received(:new)
      .with(start_date: date, end_date: date, apply: true)
    expect(chart_service).to have_received(:call)
  end

  context "when the notes scan raises" do
    before do
      allow(notes_service).to receive(:call).and_raise(StandardError, "pnet down")
    end

    it "does not abort the import" do
      expect { sync }.not_to raise_error
    end

    it "reports the failure" do
      expect { sync }.to output(/Tease sync failed/).to_stdout
    end
  end

  context "when the chart check raises" do
    before do
      allow(chart_service).to receive(:call).and_raise(StandardError, "chart down")
    end

    it "does not abort the import" do
      expect { sync }.not_to raise_error
    end
  end
end
