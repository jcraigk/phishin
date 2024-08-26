require "rails_helper"

RSpec.describe "API v2 Tags", type: :request do
  let!(:tags) do
    [
      create(:tag, name: "Classic", slug: "classic"),
      create(:tag, name: "Jam", slug: "jam")
    ]
  end

  describe "GET /api/v2/tags" do
    it "returns a list of all tags" do
      get_authorized "/api/v2/tags"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json.map { |tag| tag[:slug] }).to match_array(%w[classic jam])
    end
  end
end
