require "rails_helper"

RSpec.describe "API v2 Playlists" do
  include ApiHelper

  let!(:user) { create(:user) }
  let!(:playlist) { create(:playlist, slug: "summer-jams", name: "Summer Jams", user:) }
  let!(:track1) { create(:track) }
  let!(:track2) { create(:track) }

  before do
    playlist.playlist_tracks.create!(track: track1, position: 1)
    playlist.playlist_tracks.create!(track: track2, position: 2)
  end

  describe "GET /playlists/:slug" do
    it "returns the specified playlist by slug" do
      get_api_authed(user, "/playlists/#{playlist.slug}")

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:name]).to eq("Summer Jams")
      expect(json[:tracks].size).to eq(2)
      expect(json[:tracks].map { |t| t[:slug] }).to match_array([track1.slug, track2.slug])
    end
  end

  describe "POST /playlists" do
    context "when creating a new playlist" do
      it "creates the playlist and returns it" do
        post_api_authed(user, "/playlists", params: { name: "Road Trip", slug: "road-trip" })

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:name]).to eq("Road Trip")
        expect(json[:slug]).to eq("road-trip")
      end

      it "returns a 422 error if the playlist is invalid" do
        post_api_authed(user, "/playlists", params: { name: "RT", slug: "rt" })

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json["message"]).to include("must be between 5 and 50")
      end
    end
  end

  describe "PUT /playlists/:slug" do
    context "when updating an existing playlist" do
      it "updates the playlist name and returns it" do
        put_api_authed(user, "/playlists/#{playlist.slug}", params: { name: "Winter Jams" })

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:name]).to eq("Winter Jams")
        expect(json[:slug]).to eq("summer-jams") # Slug remains unchanged
      end

      it "returns a 422 error if the update is invalid" do
        put_api_authed(user, "/playlists/#{playlist.slug}", params: { name: "WJ" })

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json["message"]).to include("Name is invalid")
      end
    end
  end

  describe "DELETE /playlists/:slug" do
    context "when deleting an existing playlist" do
      it "deletes the playlist and returns a success message" do
        delete_api_authed(user, "/playlists/#{playlist.slug}")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:message]).to eq("Playlist deleted successfully")
        expect(Playlist.exists?(playlist.id)).to be_falsey
      end

      it "returns a 404 error if the playlist does not exist" do
        delete_api_authed(user, "/playlists/nonexistent")

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)

        expect(json["message"]).to eq("Not found")
      end
    end
  end
end
