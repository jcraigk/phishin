require "rails_helper"

RSpec.describe "API Songs" do
  let!(:songs) do
    [
      create(
        :song,
        title: "Chalk Dust Torture",
        alias: "CDT",
        artist: "Phish",
        original: true,
        slug: "chalk-dust-torture",
        tracks_count: 100
      ),
      create(
        :song,
        title: "You Enjoy Myself",
        alias: "YEM",
        artist: "Phish",
        original: true,
        slug: "you-enjoy-myself",
        tracks_count: 150
      ),
      create(
        :song,
        title: "Down with Disease",
        alias: "DWD",
        artist: "Phish",
        original: true,
        slug: "down-with-disease",
        tracks_count: 120
      )
    ]
  end

  describe "GET /songs" do
    it "returns the first page of songs sorted by title in ascending order by default" do
      get_authorized "/songs", params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      first_songs = songs.sort_by(&:title).first(2)
      expected = GrapeApi::Entities::Song.represent(first_songs).as_json
      expect(json).to eq(expected)
    end

    it "returns songs sorted by tracks_count in descending order" do
      get_authorized "/songs", params: { sort: "tracks_count:desc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      sorted_songs = songs.sort_by(&:tracks_count).reverse
      expect(json.map { |s| s["slug"] }).to eq(sorted_songs.map(&:slug))
    end

    it "filters songs by the first character of the title" do
      get_authorized "/songs", params: { first_char: "C" }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = GrapeApi::Entities::Song.represent(
        songs.select { |song| song.title.downcase.start_with?("c") }
      ).as_json
      expect(json).to eq(expected)
    end
  end

  describe "GET /songs/:slug" do
    let!(:song) { songs.first }

    it "returns the specified song by slug" do
      get_authorized "/songs/#{song.slug}"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = GrapeApi::Entities::Song.represent(song).as_json
      expect(json).to eq(expected)
    end

    it "returns a 404 if the song does not exist" do
      get_authorized "/songs/non-existent-song"
      expect(response).to have_http_status(:not_found)
    end
  end
end
