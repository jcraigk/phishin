require "rails_helper"

RSpec.describe "API v2 Reports" do
  let!(:venue1) { create(:venue, name: "Madison Square Garden", city: "New York", state: "NY") }
  let!(:venue2) { create(:venue, name: "The Roxy", city: "Atlanta", state: "GA") }
  let!(:show3) { create(:show, date: "2023-06-10", audio_status: 'partial', venue: venue1) }
  let!(:show4) { create(:show, date: "2023-05-01", audio_status: 'partial', venue: venue2) }
  let!(:missing_show1) { create(:show, date: "2023-04-01", audio_status: 'missing', venue_name: "Red Rocks - Morrison, CO", venue: venue1) }
  let!(:missing_show2) { create(:show, date: "2023-03-15", audio_status: 'missing', venue_name: "The Gorge - George, WA", venue: venue2) }
  let!(:missing_show3) { create(:show, date: "2023-01-01", audio_status: 'missing', venue_name: "The Spectrum - Philadelphia, PA", venue: venue1) }
  let(:show1) { create(:show, date: "2023-08-01", audio_status: 'complete', venue: venue1) }
  let(:show2) { create(:show, date: "2023-07-15", audio_status: 'complete', venue: venue1) }

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
          { date: missing_show1.date.to_s, venue_name: missing_show1.venue_name,
location: "#{missing_show1.venue.city}, #{missing_show1.venue.state}" },
          { date: missing_show2.date.to_s, venue_name: missing_show2.venue_name,
location: "#{missing_show2.venue.city}, #{missing_show2.venue.state}" },
          { date: missing_show3.date.to_s, venue_name: missing_show3.venue_name,
location: "#{missing_show3.venue.city}, #{missing_show3.venue.state}" }
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
