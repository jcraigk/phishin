require "rails_helper"

RSpec.describe Admin::TaginSyncJob do
  let(:admin_job) { create(:admin_job, kind: "tagin_sync") }

  it "runs the sync" do
    allow(TaginSyncService).to receive(:call).and_return([])
    described_class.new.perform(admin_job.id)
    expect(TaginSyncService).to have_received(:call)
  end

  it "completes the admin job" do
    allow(TaginSyncService).to receive(:call).and_return([])
    described_class.new.perform(admin_job.id)
    expect(admin_job.reload).to have_attributes(status: "done", progress: 100)
  end

  it "reports the tag being synced" do
    seen = nil
    allow(TaginSyncService).to receive(:call) do |progress:|
      progress.call("Tease", 5, 10)
      seen = admin_job.reload.slice(:progress, :message)
      []
    end
    described_class.new.perform(admin_job.id)
    expect(seen).to eq("progress" => 50, "message" => "Syncing Tease")
  end

  it "records per-tag results on the payload" do
    results = [
      { tag: "Tease", status: "ok" },
      { tag: "Guest", status: "failed", error: "sheet tab missing" }
    ]
    allow(TaginSyncService).to receive(:call).and_return(results)
    described_class.new.perform(admin_job.id)
    expect(admin_job.reload.payload["tags"]).to eq(
      [
        { "tag" => "Tease", "status" => "ok" },
        { "tag" => "Guest", "status" => "failed", "error" => "sheet tab missing" }
      ]
    )
  end

  it "summarizes a partial failure" do
    results = [
      { tag: "Tease", status: "ok" },
      { tag: "Guest", status: "failed", error: "sheet tab missing" }
    ]
    allow(TaginSyncService).to receive(:call).and_return(results)
    described_class.new.perform(admin_job.id)
    expect(admin_job.reload.message).to eq("Synced 1 of 2 tags, 1 failed")
  end

  it "summarizes a clean sync" do
    allow(TaginSyncService).to receive(:call).and_return([ { tag: "Tease", status: "ok" } ])
    described_class.new.perform(admin_job.id)
    expect(admin_job.reload.message).to eq("Synced 1 of 1 tags")
  end

  context "when the Google credentials are missing" do
    before do
      allow(TaginSyncService).to receive(:call).and_raise(
        TaginSyncService::SyncFailed,
        "Tagin sync failed for all 11 tags. Check GOOGLE_SPREADSHEET_CREDS and " \
        "TAGIN_GSHEET_ID. First error: No valid credentials found and not in " \
        "development environment"
      )
    end

    it "fails the admin job" do
      expect { described_class.new.perform(admin_job.id) }
        .to raise_error(TaginSyncService::SyncFailed)
      expect(admin_job.reload.status).to eq("failed")
    end

    it "names the missing credential in the message" do
      expect { described_class.new.perform(admin_job.id) }
        .to raise_error(TaginSyncService::SyncFailed)
      expect(admin_job.reload.message).to include("GOOGLE_SPREADSHEET_CREDS")
    end
  end
end
