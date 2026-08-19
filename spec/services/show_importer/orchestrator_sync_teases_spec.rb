require "rails_helper"

RSpec.describe ShowImporter::Orchestrator, "#sync_teases" do
  subject(:sync) { orchestrator.send(:sync_teases) }

  let(:date) { "1995-10-31" }
  let(:show) { create(:show, date:) }
  let(:orchestrator) { described_class.allocate }
  let(:tease_service) { instance_double(TeaseSyncService, call: nil, proposed_rows:) }
  let(:proposed_rows) { [ [ "https://phish.in/#{date}/reba", "", "", "Manteca", "", "x" ] ] }
  let(:sheet_rows) do
    [
      { "URL" => "https://phish.in/#{date}/reba", "Notes" => "Manteca" },
      { "URL" => "https://phish.in/1998-01-01/tweezer", "Notes" => "Other show" }
    ]
  end

  before do
    allow(orchestrator).to receive(:show).and_return(show)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("TAGIN_GSHEET_ID").and_return("sheet-id")
    allow(TeaseSyncService).to receive(:new).and_return(tease_service)
    allow(GoogleSpreadsheetFetcher).to receive(:call).and_return(sheet_rows)
    allow(TrackTagSyncService).to receive(:call)
  end

  it "scans the imported show with apply enabled" do
    sync

    expect(TeaseSyncService).to have_received(:new).with(date:, apply: true)
    expect(tease_service).to have_received(:call)
  end

  it "syncs only this show's rows into the database" do
    sync

    expect(TrackTagSyncService).to have_received(:call)
      .with("Tease", [ sheet_rows.first ])
  end

  context "when the scan finds nothing new" do
    let(:proposed_rows) { [] }

    it "skips the database sync" do
      sync

      expect(GoogleSpreadsheetFetcher).not_to have_received(:call)
      expect(TrackTagSyncService).not_to have_received(:call)
    end
  end

  context "when the tease scan raises" do
    before do
      allow(tease_service).to receive(:call).and_raise(StandardError, "pnet down")
    end

    it "does not abort the import" do
      expect { sync }.not_to raise_error
    end

    it "reports the failure" do
      expect { sync }.to output(/Tease sync failed/).to_stdout
    end
  end

  context "when the sheet sync raises" do
    before do
      allow(TrackTagSyncService).to receive(:call).and_raise(StandardError, "sheets down")
    end

    it "does not abort the import" do
      expect { sync }.not_to raise_error
    end
  end
end
