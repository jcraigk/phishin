require "rails_helper"

RSpec.describe "API v2 Search" do
  let!(:venue) do
    create(
      :venue,
      name: "Madison Square Garden",
      city: "New York",
      state: "NY",
      country: "USA",
      slug: "madison-square-garden"
    )
  end

  let!(:show) { create(:show, date: "2022-01-01", venue:) }
  let!(:song) { create(:song, title: "Sample Song") }
  let!(:tour) { create(:tour, name: "Winter Tour 2022") }
  let!(:tag) { create(:tag, name: "Classic") }
  let!(:show_tag) { create(:show_tag, show:, tag:) }
  let!(:track_tag) { create(:track_tag, track: create(:track, show:), tag:) }

  describe "GET /search" do
    context "when searching by term" do
      it "returns search results" do
        get_authorized "/search", params: { term: "Madison" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:venues]).to include(a_hash_including(slug: "madison-square-garden"))
      end

      it "returns shows by exact date" do
        get_authorized "/search", params: { term: "2022-01-01" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:exact_show]).to include(date: "2022-01-01")
      end

      it "returns songs matching the term" do
        get_authorized "/search", params: { term: "Sample Song" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:songs]).to include(a_hash_including(title: "Sample Song"))
      end

      it "returns tours matching the term" do
        get_authorized "/search", params: { term: "Winter Tour" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:tours]).to include(a_hash_including(name: "Winter Tour 2022"))
      end

      it "returns empty arrays for no matches" do
        get_authorized "/search", params: { term: "NonExistent" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:venues]).to eq([])
        expect(json[:exact_show]).to eq(nil)
        expect(json[:songs]).to eq([])
        expect(json[:tours]).to eq([])
      end
    end
  end
end
