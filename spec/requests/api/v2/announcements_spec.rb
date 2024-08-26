require "rails_helper"

RSpec.describe "API v2 Announcements" do
  let!(:announcements) do
    105.times.map do |i|
      create(:announcement, title: "Announcement #{i}", created_at: i.days.ago)
    end
  end

  describe "GET /api/v2/announcements" do
    it "returns the last 100 announcements ordered by created_at desc" do
      get_authorized "/api/v2/announcements"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json.size).to eq(100)

      expect(json.first[:title]).to eq("Announcement 0")
      expect(json.last[:title]).to eq("Announcement 99")
    end
  end
end
