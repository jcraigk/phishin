require "rails_helper"

RSpec.describe "API::V2::Years", type: :request do
  describe "GET /api/v2/years" do
    before do
      # Create published shows for different years and eras
      create(:show, date: "1987-05-01", published: true)
      create(:show, date: "1988-07-15", published: true)
      create(:show, date: "2003-12-01", published: true)
      create(:show, date: "2009-03-06", published: true)
      create(:show, date: "2022-08-13", published: true)
      create(:show, date: "2023-09-17", published: true)
    end

    it "returns a list of years with show counts and eras" do
      get "/api/v2/years"

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)

      # Test the first year in the response (1983-1987)
      first_period = json.find { |period| period["period"] == "1983-1987" }
      expect(first_period).to include(
        "period" => "1983-1987",
        "show_count" => 1, # Only one show in 1987
        "era" => "1.0"
      )

      # Test another year (1988)
      year_1988 = json.find { |period| period["period"] == "1988" }
      expect(year_1988).to include(
        "period" => "1988",
        "show_count" => 1, # One show in 1988
        "era" => "1.0"
      )

      # Test a year from a different era (2003)
      year_2003 = json.find { |period| period["period"] == "2003" }
      expect(year_2003).to include(
        "period" => "2003",
        "show_count" => 1, # One show in 2003
        "era" => "2.0"
      )

      # Test a year from the latest era (2022)
      year_2022 = json.find { |period| period["period"] == "2022" }
      expect(year_2022).to include(
        "period" => "2022",
        "show_count" => 1, # One show in 2022
        "era" => "4.0"
      )
    end
  end
end
