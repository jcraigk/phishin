require "rails_helper"

RSpec.describe "API v2 Shows" do
  let!(:venue) do
    create(
      :venue,
      name: "Madison Square Garden",
      city: "New York",
      state: "NY",
      country: "USA",
      latitude: 40.7505045,
      longitude: -73.9934387,
      slug: "madison-square-garden"
    )
  end
  let!(:tag) { create(:tag, name: "Classic", priority: 1) }

  describe "GET /shows" do
    let!(:shows) do
      [
        create(:show, date: "2022-01-01", likes_count: 10, duration: 120, venue:),
        create(:show, date: "2021-01-01", likes_count: 30, duration: 90, venue:),
        create(:show, date: "2023-01-01", likes_count: 20, duration: 150, venue:),
        create(:show, date: "2024-01-01", likes_count: 40, duration: 200, venue:),
        create(:show, date: "2020-01-01", likes_count: 5, duration: 110, venue:)
      ]
    end
    let!(:show_tags) do
      [
        create(:show_tag, show: shows[0], tag:, notes: "A classic show"),
        create(:show_tag, show: shows[1], tag:, notes: "Another classic show"),
        create(:show_tag, show: shows[2], tag:, notes: "Yet another classic"),
        create(:show_tag, show: shows[3], tag:, notes: ""),
        create(:show_tag, show: shows[4], tag:, notes: "")
      ]
    end

    it "returns the first page of shows sorted by date in descending order by default" do
      get_api "/shows", params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      first_show = shows.sort_by(&:date).reverse.first
      expected = ApiV2::Entities::Show.represent([ first_show ], include_tracks: false).as_json
      expect(json.first).to eq(expected.first)
    end

    it "returns the second page of shows sorted by date in descending order" do
      get_api "/shows", params: { page: 2, per_page: 2 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json.size).to eq(2)

      second_page_shows = shows.sort_by(&:date).reverse[2, 2]
      expect(json.map { |s| s["date"] }).to eq(second_page_shows.map { |show| show.date.iso8601 })
    end

    it "returns a list of shows sorted by likes_count in ascending order" do
      get_api "/shows", params: { sort: "likes_count:asc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json.map { |s| s["likes_count"] }).to eq([ 5, 10, 20 ])
    end

    it "returns a list of shows sorted by duration in descending order" do
      get_api "/shows", params: { sort: "duration:desc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json.map { |s| s["duration"] }).to eq([ 200, 150, 120 ])
    end

    it "returns a 400 error for an invalid sort parameter" do
      get_api "/shows", params: { sort: "invalid_param:asc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:bad_request)
    end

    it "filters shows by a specific year" do
      get_api "/shows", params: { year: 2022 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = ApiV2::Entities::Show.represent(
        shows.select { |show| show.date.year == 2022 },
        include_tracks: false
      ).as_json
      expect(json).to eq(expected)
    end

    it "filters shows by a year range" do
      get_api "/shows", params: { year_range: "2021-2023" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = ApiV2::Entities::Show.represent(
        shows.select { |show| show.date.year.between?(2021, 2023) },
        include_tracks: false
      ).as_json

      expected_sorted = expected.sort_by { |show| show[:date] }
      json_sorted = json.sort_by { |show| show[:date] }
      expect(json_sorted).to eq(expected_sorted)
    end

    it "gives precedence to the year over year_range when both are provided" do
      get_api "/shows", params: { year: 2022, year_range: "2021-2023" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = ApiV2::Entities::Show.represent(
        shows.select { |show| show.date.year == 2022 },
        include_tracks: false
      ).as_json
      expect(json).to eq(expected)
    end

    it "filters shows by venue_slug" do
      get_api "/shows", params: { venue_slug: "madison-square-garden" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = ApiV2::Entities::Show.represent(
        shows.sort_by(&:date).reverse,
        include_tracks: false
      ).as_json

      expect(json).to eq(expected)
    end
  end

  describe "GET /shows/:date" do
    let!(:show) { create(:show, date: "2022-01-01", venue:) }
    let!(:show_tag) { create(:show_tag, show:, tag:, notes: "A classic show") }
    let!(:tracks) do
      [
        create(:track, show:, title: "Track 1", position: 1, duration: 300, set: 1),
        create(:track, show:, title: "Track 2", position: 2, duration: 240, set: 1)
      ]
    end

    it "returns the specified show with venue, tags, and tracks" do
      get_api "/shows/#{show.date}"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = ApiV2::Entities::Show.represent(show, include_tracks: true).as_json
      expect(json).to eq(expected)
    end

    it "returns a 404 if the show does not exist" do
      get_api "/shows/1930-01-01"
      expect(response).to have_http_status(:not_found)
    end
  end
end
