require "rails_helper"

RSpec.describe "API v2 Admin Shows" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def token_for(u)
    UserJwtService.call(u)
  end

  def admin_headers
    { "X-Auth-Token" => token_for(admin) }
  end

  describe "GET /api/v2/admin/shows" do
    before do
      create(:show, date: "2024-06-01", published: false)
      create(:show, date: "2024-06-02")
    end

    it "returns 401 without a token" do
      get "/api/v2/admin/shows"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/shows", headers: { "X-Auth-Token" => token_for(user) }
      expect(response).to have_http_status(:forbidden)
    end

    it "lists draft shows for an admin" do
      get "/api/v2/admin/shows", params: { published: false }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      dates = JSON.parse(response.body)["shows"].map { |s| s["date"] }
      expect(dates).to eq([ "2024-06-01" ])
    end

    it "lists all shows without the filter" do
      get "/api/v2/admin/shows", headers: admin_headers
      expect(JSON.parse(response.body)["shows"].size).to eq(2)
    end
  end
end
