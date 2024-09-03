require "rails_helper"

RSpec.describe "API v2 Songs", type: :request do
  let!(:songs) do
    [
      create(
        :song,
        title: "You Enjoy Myself",
        slug: "you-enjoy-myself",
        original: true,
        tracks_count: 200
      ),
      create(
        :song,
        title: "Tweezer",
        slug: "tweezer",
        original: true,
        tracks_count: 150
      ),
      create(
        :song,
        title: "A Day in the Life",
        slug: "a-day-in-the-life",
        original: false,
        artist: "The Beatles",
        tracks_count: 50
      )
    ]
  end

  describe "GET /api/v2/songs" do
    it "returns the first page of songs sorted by title in ascending order by default" do
      get "/api/v2/songs", params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      first_songs = songs.sort_by(&:title).first(2)
      expected_response = {
        songs: first_songs.map { |s| ApiV2::Entities::Song.represent(s).as_json.deep_symbolize_keys },
        total_pages: (songs.count.to_f / 2).ceil,
        current_page: 1,
        total_entries: songs.count
      }
      expect(json).to eq(expected_response)
    end

    it "returns songs sorted by tracks_count in descending order" do
      get "/api/v2/songs", params: { sort: "tracks_count:desc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      sorted_songs = songs.sort_by { |s| -s.tracks_count }.first(3)
      expected_response = {
        songs: sorted_songs.map { |s| ApiV2::Entities::Song.represent(s).as_json.deep_symbolize_keys },
        total_pages: 1,
        current_page: 1,
        total_entries: songs.count
      }
      expect(json).to eq(expected_response)
    end

    it "filters songs by the first character of the title" do
      get "/api/v2/songs", params: { first_char: "T" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      filtered_songs = songs.select { |song| song.title.downcase.start_with?("t") }
      expected_response = {
        songs: filtered_songs.map { |s| ApiV2::Entities::Song.represent(s).as_json.deep_symbolize_keys },
        total_pages: 1,
        current_page: 1,
        total_entries: filtered_songs.count
      }
      expect(json).to eq(expected_response)
    end
  end

  describe "GET /api/v2/songs/:slug" do
    let!(:song) { songs.first }

    it "returns the specified song by slug" do
      get "/api/v2/songs/#{song.slug}"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected_response = ApiV2::Entities::Song.represent(song).as_json.deep_symbolize_keys
      expect(json).to eq(expected_response)
    end

    it "returns a 404 if the song does not exist" do
      get "/api/v2/songs/non-existent-song"
      expect(response).to have_http_status(:not_found)
    end
  end
end
