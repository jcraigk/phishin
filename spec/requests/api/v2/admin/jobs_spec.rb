require "rails_helper"

RSpec.describe "API v2 Admin Jobs" do
  let(:admin) { create(:user, :admin) }
  let(:admin_headers) { { "X-Auth-Token" => UserJwtService.call(admin) } }

  it "returns job state" do
    job = create(:admin_job, kind: "import", status: "running", progress: 40)
    get "/api/v2/admin/jobs/#{job.id}", headers: admin_headers
    body = JSON.parse(response.body)
    expect(body["status"]).to eq("running")
    expect(body["progress"]).to eq(40)
  end

  it "requires admin" do
    job = create(:admin_job)
    get "/api/v2/admin/jobs/#{job.id}"
    expect(response).to have_http_status(:unauthorized)
  end
end
