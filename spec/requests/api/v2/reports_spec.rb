require "rails_helper"

RSpec.describe "API v2 Reports" do
  let!(:show1) { create(:show, date: "2023-08-01", incomplete: false, published: true) }
  let!(:show2) { create(:show, date: "2023-07-15", incomplete: false, published: true) }

  let!(:show3) { create(:show, date: "2023-06-10", incomplete: true, published: true) }
  let!(:show4) { create(:show, date: "2023-05-01", incomplete: true, published: true) }

  let!(:known_date1) { create(:known_date, date: "2023-04-01") }
  let!(:known_date2) { create(:known_date, date: "2023-03-15") }
  let!(:known_date3) { create(:known_date, date: "2023-01-01") }

  describe "GET /api/v2/reports/missing_content" do
    it "returns a list of missing and incomplete content in descending date order" do
      get "/api/v2/reports/missing_content"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)

      expected_response = {
        missing_show_dates: [known_date1.date.to_s, known_date2.date.to_s, known_date3.date.to_s],
        incomplete_show_dates: [show3.date.to_s, show4.date.to_s]
      }

      expect(json).to eq(expected_response)
    end
  end
end
