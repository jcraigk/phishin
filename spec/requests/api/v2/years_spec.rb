require "rails_helper"

RSpec.describe "API v2 Years" do
  describe "GET /api/v2/years" do
    before do
      # Create published shows for different years and eras
      create(:show, date: "1987-05-01", published: true)
      create(:show, date: "1986-07-15", published: true)
      create(:show, date: "2003-12-01", published: true)
    end

    it "returns a list of years with show counts and eras" do
      get_authorized "/api/v2/years"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)

      # Test the first year in the response (1983-1987)
      first_period = json.find { |period| period["period"] == "1983-1987" }
      expect(first_period).to include(
        "period" => "1983-1987",
        "shows_count" => 2,
        "era" => "1.0"
      )

      # Test a year from a different era (2003)
      year_2003 = json.find { |period| period["period"] == "2003" }
      expect(year_2003).to include(
        "period" => "2003",
        "shows_count" => 1,
        "era" => "2.0"
      )
    end
  end
end
