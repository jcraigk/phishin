require "rails_helper"

RSpec.describe "API v2 Shows" do
  let!(:venue_ny) { create(:venue, state: "NY", slug: "madison-square-garden") }
  let!(:venue_ca) { create(:venue, state: "CA", slug: "staples-center") }
  let!(:venue_il) { create(:venue, state: "IL", slug: "united-center") }

  let!(:shows) do
    [
      create(:show, date: "2021-01-01", likes_count: 10, duration: 120, venue: venue_ny),
      create(:show, date: "2022-02-01", likes_count: 30, duration: 90, venue: venue_ca),
      create(:show, date: "2023-03-01", likes_count: 20, duration: 150, venue: venue_il),
      create(:show, date: "2024-04-01", likes_count: 40, duration: 200, venue: venue_ny),
      create(:show, date: "2025-05-01", likes_count: 5, duration: 110, venue: venue_ca)
    ]
  end

  describe "GET /shows" do
    it "returns the first page of shows" do
      get_api "/shows", params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      shows_data = json[:shows]
      expect(shows_data.length).to eq(2)

      expect(json[:total_pages]).to eq(3)
      expect(json[:current_page]).to eq(1)
      expect(json[:total_entries]).to eq(5)

      first_page_shows = shows.sort_by(&:date).reverse.take(2) # date:desc order
      expected = ApiV2::Entities::Show.represent(first_page_shows, include_tracks: false).as_json
      expect(shows_data).to eq(expected)
    end

    it "returns shows filtered by start_date and end_date," do
      get_api "/shows", params: { start_date: "2022-01-01", end_date: "2024-12-31" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      shows_data = json[:shows]
      filtered_shows = shows.select { |show| show.date.between?(Date.parse("2022-01-01"), Date.parse("2024-12-31")) }
                            .sort_by(&:date).reverse # Ensure date:desc order
      expected = ApiV2::Entities::Show.represent(filtered_shows, include_tracks: false).as_json

      expect(shows_data).to eq(expected)
    end

    it "returns shows filtered by a specific year" do
      get_api "/shows", params: { year: 2022 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      shows_data = json[:shows]
      filtered_shows = shows.select { |show| show.date.year == 2022 }
                            .sort_by(&:date).reverse # Ensure date:desc order
      expected = ApiV2::Entities::Show.represent(filtered_shows, include_tracks: false).as_json

      expect(shows_data).to eq(expected)
    end

    it "returns shows filtered by a year range," do
      get_api "/shows", params: { year_range: "2021-2023" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      shows_data = json[:shows]
      filtered_shows = shows.select { |show| show.date.year.between?(2021, 2023) }
                            .sort_by(&:date).reverse # Ensure date:desc order
      expected = ApiV2::Entities::Show.represent(filtered_shows, include_tracks: false).as_json

      expect(shows_data).to eq(expected)
    end

    it "returns shows filtered by us_state" do
      get_api "/shows", params: { us_state: "NY" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      shows_data = json[:shows]
      filtered_shows = shows.select { |show| show.venue.state == "NY" }
                            .sort_by(&:date).reverse # Ensure date:desc order
      expected = ApiV2::Entities::Show.represent(filtered_shows, include_tracks: false).as_json

      expect(shows_data).to eq(expected)
    end
  end

  describe "GET /shows/random" do
    it "returns a random published show" do
      get_api "/shows/random"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json).to be_present
      expect(json[:date]).to be_present
      expect(json[:venue][:state]).to be_present
    end
  end

  describe "GET /shows/:id" do
    let!(:show) { create(:show, date: "2022-01-01", venue: venue_ny) }

    it "returns the specified show" do
      get_api "/shows/#{show.id}"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = ApiV2::Entities::Show.represent(show, include_tracks: true).as_json
      expect(json).to eq(expected)
    end

    it "returns a 404 if the show does not exist" do
      get_api "/shows/9999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /shows/on_date/:date" do
    let!(:show) { create(:show, date: "2022-01-01", venue: venue_ny) }

    it "returns the specified show with venue, tags, and tracks" do
      get_api "/shows/on_date/#{show.date}"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = ApiV2::Entities::Show.represent(show, include_tracks: true).as_json
      expect(json).to eq(expected)
    end

    it "returns a 404 if the show does not exist" do
      get_api "/shows/on_date/1930-01-01"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /shows/on_day_of_year/:date" do
    it "returns shows for a specific day of the year given a date" do
      get_api "/shows/on_day_of_year/2022-02-01"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json.size).to eq(1)
      expect(json.first[:date]).to eq("2022-02-01")
    end

    it "returns a 400 error for an invalid date format" do
      get_api "/shows/on_day_of_year/invalid-date"
      expect(response).to have_http_status(:bad_request)
    end
  end
end
