require "rails_helper"

RSpec.describe "API v2 Playlists", type: :request do
  let!(:playlist) do
    create(:playlist, slug: "summer-jams", name: "Summer Jams")
  end
  let!(:track1) { create(:track) }
  let!(:track2) { create(:track) }

  before do
    playlist.playlist_tracks.create!(track: track1, position: 1)
    playlist.playlist_tracks.create!(track: track2, position: 2)
  end

  describe "GET /api/v2/playlists/:slug" do
    it "returns the specified playlist by slug" do
      get_authorized "/api/v2/playlists/#{playlist.slug}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:name]).to eq("Summer Jams")
      expect(json[:tracks].size).to eq(2)
      expect(json[:tracks].map { |t| t[:slug] }).to match_array([ track1.slug, track2.slug ])
    end
  end
end
