require "rails_helper"

RSpec.describe "API v2 Venues" do
  let!(:venues) do
    [
      create(
        :venue,
        name: "Madison Square Garden",
        city: "New York",
        state: "NY",
        country: "USA",
        latitude: 40.7505045,
        longitude: -73.9934387,
        slug: "madison-square-garden",
        shows_count: 150
      ),
      create(
        :venue,
        name: "The Fillmore",
        city: "San Francisco",
        state: "CA",
        country: "USA",
        latitude: 37.784137,
        longitude: -122.432713,
        slug: "the-fillmore",
        shows_count: 100
      ),
      create(
        :venue,
        name: "Alpine Valley Music Theatre",
        city: "East Troy",
        state: "WI",
        country: "USA",
        latitude: 42.702981,
        longitude: -88.426749,
        slug: "alpine-valley-music-theatre",
        shows_count: 50
      )
    ]
  end

  describe "GET /api/v2/venues" do
    it "returns the first page of venues sorted by name in ascending order by default" do
      get_authorized "/api/v2/venues", params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      first_venue = venues.sort_by(&:name).first(2) # adjust to reflect pagination
      expected = GrapeApi::Entities::Venue.represent(first_venue).as_json
      expect(json).to eq(expected)
    end

    it "returns venues sorted by shows_count in descending order" do
      get_authorized "/api/v2/venues", params: { sort: "shows_count:desc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      sorted_venues = venues.sort_by { |v| -v.shows_count }.first(3)
      expect(json.map { |v| v["slug"] }).to eq(sorted_venues.map(&:slug))
    end

    it "filters venues by the first character of the name" do
      get_authorized "/api/v2/venues", params: { first_char: "M" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = GrapeApi::Entities::Venue.represent(
        venues.select { |venue| venue.name.downcase.start_with?("m") }
      ).as_json
      expect(json).to eq(expected)
    end
  end

  describe "GET /api/v2/venues/:slug" do
    let!(:venue) { venues.first }

    it "returns the specified venue by slug" do
      get_authorized "/api/v2/venues/#{venue.slug}"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = GrapeApi::Entities::Venue.represent(venue).as_json
      expect(json).to eq(expected)
    end

    it "returns a 404 if the venue does not exist" do
      get_authorized "/api/v2/venues/non-existent-venue"
      expect(response).to have_http_status(:not_found)
    end
  end
end
