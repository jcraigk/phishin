require "rails_helper"

RSpec.describe "API v2 Tracks" do
  let!(:tag) { create(:tag, name: "Classic", priority: 1) }
  let!(:tracks) do
    [
      create(:track, title: "Track 1", position: 1, duration: 300, likes_count: 10),
      create(:track, title: "Track 2", position: 2, duration: 240, likes_count: 20),
      create(:track, title: "Track 3", position: 3, duration: 360, likes_count: 5),
      create(:track, title: "Track 4", position: 4, duration: 180, likes_count: 15)
    ]
  end
  let!(:track_tags) do
    [
      create(:track_tag, track: tracks[0], tag:, notes: "A classic track"),
      create(:track_tag, track: tracks[1], tag:, notes: "Another classic track"),
      create(:track_tag, track: tracks[2], tag:, notes: "")
    ]
  end

  describe "GET /tracks" do
    it "returns the first page of tracks sorted by id in ascending order by default" do
      get_api "/tracks", params: { page: 1, per_page: 2 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      sorted_tracks = tracks.sort_by(&:id).take(2)
      expected = ApiV2::Entities::Track.represent(sorted_tracks, show_details: true).as_json
      expect(json).to eq(expected)
    end

    it "filters tracks by tag_slug" do
      get_api "/tracks", params: { tag_slug: tag.slug }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      filtered_tracks = tracks.select { |track| track.tags.include?(tag) }
      filtered_tracks_sorted = filtered_tracks.sort_by(&:id)
      expected = ApiV2::Entities::Track.represent(filtered_tracks_sorted,
show_details: true).as_json
      expect(json).to eq(expected)
    end

    it "returns a list of tracks sorted by likes_count in descending order" do
      get_api "/tracks", params: { sort: "likes_count:desc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      sorted_tracks = tracks.sort_by(&:likes_count).reverse.take(3)
      expected = ApiV2::Entities::Track.represent(sorted_tracks, show_details: true).as_json
      expect(json).to eq(expected)
    end

    it "returns a list of tracks sorted by duration in ascending order" do
      get_api "/tracks", params: { sort: "duration:asc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      sorted_tracks = tracks.sort_by(&:duration).take(3)
      expected = ApiV2::Entities::Track.represent(sorted_tracks, show_details: true).as_json
      expect(json).to eq(expected)
    end

    it "returns a 400 error for an invalid sort parameter" do
      get_api "/tracks", params: { sort: "invalid_param:asc", page: 1, per_page: 3 }
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /tracks/:id" do
    it "returns the specified track with show details, tags, and songs" do
      track = tracks.first
      get_api "/tracks/#{track.id}"
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expected = ApiV2::Entities::Track.represent(track, show_details: true).as_json
      expect(json).to eq(expected)
    end

    it "returns a 404 if the track does not exist" do
      get_api "/tracks/9999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
