require "rails_helper"

RSpec.describe "API v2 Search" do
  include ApiHelper

  let!(:user) { create(:user) }
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
  let!(:tag) { create(:tag, name: "Classic") }
  let(:song) { create(:song, title: "Sample Song") }
  let(:tour) { create(:tour, name: "Winter Tour 2022") }
  let(:show_tag) { create(:show_tag, show:, tag:) }
  let(:track_tag) { create(:track_tag, track: create(:track, show:), tag:) }

  before do
    song
    tour
    show_tag
    track_tag
  end

  describe "GET /search" do
    context "when searching by term" do
      it "returns search results for venues" do
        get_api_authed(user, "/search/Madison")
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:venues]).to include(a_hash_including(slug: "madison-square-garden"))
      end

      it "returns shows by exact date" do
        get_api_authed(user, "/search/2022-01-01")
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:exact_show]).to include(date: "2022-01-01")
      end

      it "returns songs matching the term" do
        get_api_authed(user, "/search/Sample%20Song")
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:songs]).to include(a_hash_including(title: "Sample Song"))
      end

      it "returns empty arrays for no matches" do
        get_api_authed(user, "/search/NonExistent")
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:venues]).to eq([])
        expect(json[:exact_show]).to be_nil
        expect(json[:songs]).to eq([])
      end

      it "returns a 400 error when the term is too short" do
        get_api_authed(user, "/search/Ma")
        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq("Term too short")
      end
    end
  end
end
