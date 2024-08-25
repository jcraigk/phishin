require "rails_helper"

RSpec.describe "API::V2::Shows", type: :request do
  describe "GET /api/v2/shows" do
    let!(:venue) { create(:venue, name: "Madison Square Garden", city: "New York", state: "NY", country: "USA", latitude: 40.7505045, longitude: -73.9934387, slug: "madison-square-garden") }
    let!(:tag) { create(:tag, name: "Classic", priority: 1) }
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
      get "/api/v2/shows", params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(2)

      first_show = shows.sort_by(&:date).reverse.first
      expect(json.first).to include(
        "date" => first_show.date.iso8601,
        "duration" => first_show.duration,
        "venue_name" => first_show.venue.name,
        "venue_latitude" => first_show.venue.latitude,
        "venue_longitude" => first_show.venue.longitude,
        "venue_location" => first_show.venue.location,
        "venue_slug" => first_show.venue.slug,
        "tags" => first_show.show_tags.map { |show_tag| { "name" => show_tag.tag.name, "priority" => show_tag.tag.priority, "notes" => show_tag.notes } }
      )
    end

    it "returns the second page of shows sorted by date in descending order" do
      get "/api/v2/shows", params: { page: 2, per_page: 2 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(2)

      second_page_shows = shows.sort_by(&:date).reverse[2, 2]
      expect(json.map { |s| s["date"] }).to eq(second_page_shows.map { |show| show.date.iso8601 })
    end

    it "returns a list of shows sorted by likes_count in ascending order" do
      get "/api/v2/shows", params: { sort: "likes_count:asc", page: 1, per_page: 3 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |s| s["likes_count"] }).to eq([5, 10, 20])
    end

    it "returns a list of shows sorted by duration in descending order" do
      get "/api/v2/shows", params: { sort: "duration:desc", page: 1, per_page: 3 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { |s| s["duration"] }).to eq([200, 150, 120])
    end

    it "returns a 400 error for an invalid sort parameter" do
      get "/api/v2/shows", params: { sort: "invalid_param:asc", page: 1, per_page: 3 }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/v2/shows/:date" do
    let!(:venue) { create(:venue, name: "Madison Square Garden", city: "New York", state: "NY", country: "USA", latitude: 40.7505045, longitude: -73.9934387, slug: "madison-square-garden") }
    let!(:tag) { create(:tag, name: "Classic", priority: 1) }
    let!(:show) { create(:show, date: "2022-01-01", venue:) }
    let!(:show_tag) { create(:show_tag, show:, tag:, notes: "A classic show") }

    it "returns the specified show with venue and tags" do
      get "/api/v2/shows/#{show.date}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        "date" => show.date.iso8601,
        "duration" => show.duration,
        "venue_name" => show.venue.name,
        "venue_latitude" => show.venue.latitude,
        "venue_longitude" => show.venue.longitude,
        "venue_location" => show.venue.location,
        "venue_slug" => show.venue.slug,
        "tags" => show.show_tags.map { |st| { "name" => st.tag.name, "priority" => st.tag.priority, "notes" => st.notes } }
      )
    end

    it "returns a 404 if the show does not exist" do
      get "/api/v2/shows/1930-01-01"

      expect(response).to have_http_status(:not_found)
    end
  end
end
