require "rails_helper"

RSpec.describe "API::V2::Shows", type: :request do
  describe "GET /api/v2/shows" do
    let!(:shows) { create_list(:show, 3) }

    it "returns a list of shows" do
      get "/api/v2/shows"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(3)
      expect(json.first).to include(
        "id" => shows.first.id,
        "date" => shows.first.date.iso8601,
        "duration" => shows.first.duration
      )
    end
  end

  describe "GET /api/v2/shows/:id" do
    let!(:show) { create(:show) }

    it "returns the specified show" do
      get "/api/v2/shows/#{show.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        "id" => show.id,
        "date" => show.date.iso8601,
        "duration" => show.duration
      )
    end

    it "returns a 404 if the show does not exist" do
      get "/api/v2/shows/999999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
