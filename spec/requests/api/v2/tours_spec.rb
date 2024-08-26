require "rails_helper"

RSpec.describe "API v2 Tours", type: :request do
  let!(:tour1) do
    create(
      :tour,
      name: "Summer Tour 2022",
      starts_on: "2022-06-01",
      ends_on: "2022-08-01",
      shows_count: 10,
      slug: "summer-tour-2022"
    )
  end

  let!(:tour2) do
    create(
      :tour,
      name: "Winter Tour 2023",
      starts_on: "2023-01-01",
      ends_on: "2023-03-01",
      shows_count: 8,
      slug: "winter-tour-2023"
    )
  end

  let!(:tour3) do
    create(
      :tour,
      name: "Fall Tour 2022",
      starts_on: "2022-09-01",
      ends_on: "2022-11-01",
      shows_count: 12,
      slug: "fall-tour-2022"
    )
  end

  describe "GET /api/v2/tours" do
    it "returns the first page of tours sorted by starts_on in ascending order by default" do
      get_authorized "/api/v2/tours", params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = GrapeApi::Entities::Tour.represent([ tour1, tour3 ]).as_json
      expect(json).to eq(expected)
    end

    it "returns the tours sorted by name in descending order" do
      get_authorized "/api/v2/tours", params: { sort: "name:desc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      sorted_tours = [ tour2, tour3, tour1 ].sort_by(&:name).reverse
      expected = GrapeApi::Entities::Tour.represent(sorted_tours).as_json

      expect(json).to eq(expected)
    end

    it "returns the tours sorted by shows_count in ascending order" do
      get_authorized "/api/v2/tours", params: { sort: "shows_count:asc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      sorted_tours = [tour2, tour1, tour3].sort_by(&:shows_count)
      expected = GrapeApi::Entities::Tour.represent(sorted_tours).as_json

      expect(json).to eq(expected)
    end

    it "returns a 400 error for an invalid sort parameter" do
      get_authorized "/api/v2/tours", params: { sort: "invalid_param:asc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/v2/tours/:slug" do
    let!(:show1) do
      create(
        :show,
        tour: tour1,
        date: "2022-06-15"
      )
    end

    let!(:show2) do
      create(
        :show,
        tour: tour1,
        date: "2022-07-10"
      )
    end

    it "returns the specified tour by slug, including shows" do
      get_authorized "/api/v2/tours/#{tour1.slug}"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = GrapeApi::Entities::Tour.represent(tour1, include_shows: true).as_json
      expect(json).to eq(expected)
    end

    it "returns a 404 if the tour does not exist" do
      get_authorized "/api/v2/tours/non-existent-slug"
      expect(response).to have_http_status(:not_found)
    end
  end
end
