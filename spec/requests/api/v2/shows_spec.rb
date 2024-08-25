require "rails_helper"

RSpec.describe "API::V2::Shows", type: :request do
  describe "GET /api/v2/shows" do
    let!(:shows) do
      [
        create(:show, date: "2022-01-01", likes_count: 10, duration: 120),
        create(:show, date: "2021-01-01", likes_count: 30, duration: 90),
        create(:show, date: "2023-01-01", likes_count: 20, duration: 150)
      ]
    end

    it "returns a list of shows sorted by date in descending order by default" do
      get "/api/v2/shows"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(3)
      expect(json.map { |s| s["date"] }).to eq(
        shows.sort_by(&:date).reverse.map { |s| s.date.iso8601 }
      )
    end

    it "returns a list of shows sorted by likes_count in ascending order" do
      get "/api/v2/shows", params: { sort: "likes_count:asc" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |s| s["likes_count"] }).to eq([10, 20, 30])
    end

    it "returns a list of shows sorted by duration in descending order" do
      get "/api/v2/shows", params: { sort: "duration:desc" }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |s| s["duration"] }).to eq([150, 120, 90])
    end

    it "returns a 400 error for invalid sort parameter" do
      get "/api/v2/shows", params: { sort: "invalid_param:asc" }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/v2/shows/:date" do
    let!(:show) { create(:show) }

    it "returns the specified show" do
      get "/api/v2/shows/#{show.date}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        "date" => show.date.iso8601,
        "duration" => show.duration
      )
    end

    it "returns a 404 if the show does not exist" do
      get "/api/v2/shows/1930-01-01"

      expect(response).to have_http_status(:not_found)
    end
  end
end
