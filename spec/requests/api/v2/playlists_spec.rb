require "rails_helper"

RSpec.describe "API v2 Playlists" do
  include ApiHelper

  let!(:user) { create(:user) }
  let!(:playlist) do
    create(
      :playlist,
      slug: "summer-jams",
      name: "Summer Jams",
      description: "The best summer jams",
      user:,
      tracks_count: 2
    )
  end
  let!(:track1) { playlist.tracks.first }
  let!(:track2) { playlist.tracks.second }
  let!(:track3) { create(:track) }

  describe "GET /playlists" do
    let!(:unpublished_playlist) { create(:playlist, published: false, user:) }
    let!(:liked_playlist) { create(:playlist) }
    let(:like) { create(:like, user:, likable: liked_playlist) }
    let(:published_playlist) { create(:playlist, published: true) }

    before do
      like
      published_playlist
    end

    context "when fetching all playlists" do
      it "returns a list of published playlists" do
        get_api_authed(user, "/playlists")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:playlists]).to be_an(Array)
        expect(json[:playlists].size).to eq(3)
      end
    end

    context "when filtering by liked playlists" do
      it "returns a list of liked playlists for the user" do
        get_api_authed(user, "/playlists", params: { filter: "liked" })

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:playlists]).to be_an(Array)
        expect(json[:playlists].size).to eq(1)
        expect(json[:playlists].first[:slug]).to eq(liked_playlist.slug)
        expect(json[:total_entries]).to eq(1)
      end
    end

    context "when filtering by user's own playlists" do
      it "returns a list of user's playlists" do
        get_api_authed(user, "/playlists", params: { filter: "mine" })

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:playlists]).to be_an(Array)
        expect(json[:playlists].size).to eq(2)
        expect(json[:playlists].first[:slug]).to eq(unpublished_playlist.slug)
        expect(json[:total_entries]).to eq(2)
      end
    end

    context "when sorting by likes_count in descending order" do
      it "returns playlists sorted by likes_count" do
        get_api_authed(user, "/playlists", params: { sort: "likes_count:desc" })

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:playlists]).to be_an(Array)
        expect(json[:playlists].first[:likes_count]).to eq(liked_playlist.likes.count)
      end
    end

    context "when no playlists are found" do
      before { Playlist.delete_all }

      it "returns an empty list" do
        get_api_authed(user, "/playlists")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:playlists]).to be_empty
        expect(json[:total_entries]).to eq(0)
      end
    end
  end

  describe "GET /playlists/:slug" do
    it "returns the specified playlist by slug" do
      get_api_authed(user, "/playlists/#{playlist.slug}")

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:name]).to eq("Summer Jams")
      expect(json[:entries].size).to eq(2)
      expect(json[:entries].map { it[:track][:slug] }).to contain_exactly(track1.slug, track2.slug)
    end
  end

  describe "POST /playlists" do
    context "when creating a new playlist" do
      it "creates the playlist and returns it with associated tracks" do
        post_api_authed(
          user,
          "/playlists",
          params: {
            name: "Road Trip",
            slug: "road-trip",
            description: "Road trip playlist",
            published: true,
            track_ids: [ track1.id, track2.id ],
            starts_at_seconds: [ 0, 15 ],
            ends_at_seconds: [ 120, 180 ]
          }
        )

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:name]).to eq("Road Trip")
        expect(json[:slug]).to eq("road-trip")
        expect(json[:entries].size).to eq(2)
        expect(json[:entries].map { it[:track][:id] }).to contain_exactly(track1.id, track2.id)
      end

      it "returns a 422 error if the playlist is invalid" do
        post_api_authed(
          user,
          "/playlists",
          params: {
            name: "RT", # Too short
            slug: "road-trip",
            description: "Road trip playlist",
            published: true,
            track_ids: [ track1.id, track2.id ],
            starts_at_seconds: [ 0, 15 ],
            ends_at_seconds: [ 120, 180 ]
          }
        )

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)

        expect(json["message"]).to include("Name is invalid")
      end
    end
  end

  describe "PUT /playlists/:id" do
    context "when updating an existing playlist" do
      it "updates the playlist name and associated tracks" do
        put_api_authed(
          user,
          "/playlists/#{playlist.id}",
          params: {
            name: "Winter Jams #2",
            description: "Winter jams playlist",
            slug: "winter-jams-2",
            published: false,
            track_ids: [ track2.id, track3.id ],
            starts_at_seconds: [ 0, 15 ],
            ends_at_seconds: [ 120, 180 ]
          }
        )

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:name]).to eq("Winter Jams #2")
        expect(json[:description]).to eq("Winter jams playlist")
        expect(json[:slug]).to eq("winter-jams-2")
        expect(json[:published]).to be(false)
        expect(json[:entries].size).to eq(2)
        expect(json[:entries].map { it[:track][:id] }).to eq([ track2.id, track3.id ])
        expect(json[:entries].map { it[:starts_at_second] }).to eq([ nil, 15 ])
      end

      it "returns a 422 error if the update is invalid" do
        put_api_authed(
          user,
          "/playlists/#{playlist.id}",
          params: {
            name: "WJ",
            description: "Winter jams playlist",
            slug: "wj",
            published: true,
            track_ids: [],
            starts_at_seconds: [],
            ends_at_seconds: []
          }
        )
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["message"]).to include("Name is invalid")
      end
    end
  end

  describe "DELETE /playlists/:id" do
    context "when deleting an existing playlist" do
      it "deletes the playlist and returns a success message" do
        delete_api_authed(user, "/playlists/#{playlist.id}")
        expect(response).to have_http_status(:no_content)
      end

      it "returns a 404 error if the playlist does not exist" do
        delete_api_authed(user, "/playlists/9999")

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)

        expect(json["message"]).to eq("Not found")
      end
    end
  end
end
