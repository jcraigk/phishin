require "rails_helper"

RSpec.describe "API v2 Reports" do
  let!(:venue1) { create(:venue, name: "Madison Square Garden", city: "New York", state: "NY") }
  let!(:venue2) { create(:venue, name: "The Roxy", city: "Atlanta", state: "GA") }
  let!(:show3) { create(:show, date: "2023-06-10", incomplete: true, published: true, venue: venue1) }
  let!(:show4) { create(:show, date: "2023-05-01", incomplete: true, published: true, venue: venue2) }
  let!(:known_date1) { create(:known_date, date: "2023-04-01", venue: "Red Rocks", location: "Morrison, CO") }
  let!(:known_date2) { create(:known_date, date: "2023-03-15", venue: "The Gorge", location: "George, WA") }
  let!(:known_date3) { create(:known_date, date: "2023-01-01", venue: "The Spectrum", location: "Philadelphia, PA") }
  let(:show1) { create(:show, date: "2023-08-01", incomplete: false, published: true, venue: venue1) }
  let(:show2) { create(:show, date: "2023-07-15", incomplete: false, published: true, venue: venue1) }

  before do
    show1
    show2
  end

  describe "GET /api/v2/reports/missing_content" do
    it "returns a list of missing and incomplete content with date, venue_name," \
       " and location in descending date order" do
      get "/api/v2/reports/missing_content"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)

      expected_response = {
        missing_shows: [
          { date: known_date1.date.to_s, venue_name: known_date1.venue,
location: known_date1.location },
          { date: known_date2.date.to_s, venue_name: known_date2.venue,
location: known_date2.location },
          { date: known_date3.date.to_s, venue_name: known_date3.venue,
location: known_date3.location }
        ],
        incomplete_shows: [
          { date: show3.date.to_s, venue_name: show3.venue.name,
location: "#{show3.venue.city}, #{show3.venue.state}" },
          { date: show4.date.to_s, venue_name: show4.venue.name,
location: "#{show4.venue.city}, #{show4.venue.state}" }
        ]
      }

      expect(json).to eq(expected_response)
    end
  end
end
