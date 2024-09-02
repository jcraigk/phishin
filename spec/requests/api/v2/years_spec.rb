require "rails_helper"

RSpec.describe "API v2 Years" do
  describe "GET /years" do
    before do
      venue1 = create(:venue)
      venue2 = create(:venue)

      create(:show, date: "1987-05-01", published: true, venue: venue1)
      create(:show, date: "1986-07-15", published: true, venue: venue1)
      create(:show, date: "2003-12-01", published: true, venue: venue2)
    end

    it "returns a list of years with show counts, venue counts, and eras" do
      get_api "/years"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)

      # Test the first year in the response (1983-1987)
      first_period = json.find { |period| period["period"] == "1983-1987" }
      expect(first_period).to include(
        "period" => "1983-1987",
        "shows_count" => 2,
        "venues_count" => 1,
        "era" => "1.0"
      )

      # Test a year from a different era (2003)
      year_2003 = json.find { |period| period["period"] == "2003" }
      expect(year_2003).to include(
        "period" => "2003",
        "shows_count" => 1,
        "venues_count" => 1,
        "era" => "2.0"
      )
    end
  end
end
