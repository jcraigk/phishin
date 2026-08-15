require "rails_helper"

# The endpoint only enqueues a Sidekiq job, and Sidekiq::Testing.fake!
# (spec/support/sidekiq.rb) leaves it on the queue rather than running it, so no
# example here reaches the Google Sheets API.
RSpec.describe "API v2 Admin Tagin" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:path) { "/api/v2/admin/tagin_sync" }

  def token_for(u)
    UserJwtService.call(u)
  end

  def admin_headers
    { "X-Auth-Token" => token_for(admin), "CONTENT_TYPE" => "application/json" }
  end

  def user_headers
    { "X-Auth-Token" => token_for(user), "CONTENT_TYPE" => "application/json" }
  end

  def anon_headers
    { "CONTENT_TYPE" => "application/json" }
  end

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  describe "POST /api/v2/admin/tagin_sync" do
    it "creates a tagin sync job" do
      post path, headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(AdminJob.last).to have_attributes(kind: "tagin_sync", status: "queued")
    end

    it "returns the job id" do
      post path, headers: admin_headers
      expect(json[:job_id]).to eq(AdminJob.last.id)
    end

    it "enqueues the sync job" do
      post path, headers: admin_headers
      expect(Admin::TaginSyncJob.jobs.size).to eq(1)
    end

    it "returns 401 without a token and syncs nothing" do
      allow(TaginSyncService).to receive(:call)
      post path, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(AdminJob.count).to eq(0)
      expect(Admin::TaginSyncJob.jobs).to be_empty
      expect(TaginSyncService).not_to have_received(:call)
    end

    it "returns 403 for a non-admin user and syncs nothing" do
      allow(TaginSyncService).to receive(:call)
      post path, headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(AdminJob.count).to eq(0)
      expect(Admin::TaginSyncJob.jobs).to be_empty
      expect(TaginSyncService).not_to have_received(:call)
    end
  end

  describe "POST /api/v2/admin/tagin_drift" do
    let(:path) { "/api/v2/admin/tagin_drift" }

    it "creates a tagin drift job" do
      post path, headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(AdminJob.last).to have_attributes(kind: "tagin_drift", status: "queued")
    end

    it "returns the job id" do
      post path, headers: admin_headers
      expect(json[:job_id]).to eq(AdminJob.last.id)
    end

    it "enqueues the drift job" do
      post path, headers: admin_headers
      expect(Admin::TaginDriftJob.jobs.size).to eq(1)
    end

    it "returns 401 without a token and fetches nothing" do
      allow(GoogleSpreadsheetFetcher).to receive(:call)
      post path, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
      expect(AdminJob.count).to eq(0)
      expect(Admin::TaginDriftJob.jobs).to be_empty
      expect(GoogleSpreadsheetFetcher).not_to have_received(:call)
    end

    it "returns 403 for a non-admin user and fetches nothing" do
      allow(GoogleSpreadsheetFetcher).to receive(:call)
      post path, headers: user_headers
      expect(response).to have_http_status(:forbidden)
      expect(AdminJob.count).to eq(0)
      expect(Admin::TaginDriftJob.jobs).to be_empty
      expect(GoogleSpreadsheetFetcher).not_to have_received(:call)
    end
  end
end
