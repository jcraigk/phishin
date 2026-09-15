require "rails_helper"

RSpec.describe ShowImporter::Orchestrator, "#enrich_from_phishnet" do
  subject(:enrich) { orchestrator.send(:enrich_from_phishnet) }

  let(:date) { "1995-10-31" }
  let(:show) { create(:show, date:) }
  let(:orchestrator) { described_class.allocate }
  let(:notes_service) { instance_double(TeaseSyncService, call: nil) }
  let(:chart_service) { instance_double(TeaseChartSyncService, call: nil) }

  before do
    allow(orchestrator).to receive(:show).and_return(show)
    allow(DebutTagService).to receive(:call)
    allow(LoreSyncService).to receive(:call)
    allow(TeaseSyncService).to receive(:new).and_return(notes_service)
    allow(TeaseChartSyncService).to receive(:new).and_return(chart_service)
  end

  it "runs every Phish.net enrichment step for the show" do
    expect { enrich }.to output.to_stdout

    expect(DebutTagService).to have_received(:call).with(show)
    expect(LoreSyncService).to have_received(:call).with(date:)
    expect(TeaseSyncService).to have_received(:new).with(date:, apply: true)
    expect(TeaseChartSyncService).to have_received(:new).with(start_date: date, end_date: date, apply: true)
  end

  context "when a step raises" do
    before do
      allow(notes_service).to receive(:call).and_raise(StandardError, "pnet down")
    end

    it "does not abort the import" do
      expect { enrich }.to output(/pnet down/).to_stdout
      expect(chart_service).to have_received(:call)
    end
  end
end
