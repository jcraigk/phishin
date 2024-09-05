require "rails_helper"

RSpec.describe "API v2 Likes" do
  let!(:user) { create(:user) }
  let!(:show) { create(:show) }
  let!(:track) { create(:track) }

  describe "POST /likes" do
    context "when liking a show" do
      it "creates a like for the show" do
        expect {
          post_api_authed(
            user,
            "/likes",
            params: { likable_type: "Show", likable_id: show.id }
          )
        }.to change { show.likes.count }.by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "when liking a track" do
      it "creates a like for the track" do
        expect {
          post_api_authed(
            user,
            "/likes",
            params: { likable_type: "Track", likable_id: track.id }
          )
        }.to change { track.likes.count }.by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "when trying to like an invalid object" do
      it "returns a 422 Unprocessable Entity error" do
        post_api_authed(
          user,
          "/likes",
          params: { likable_type: "Track", likable_id: 0 }
        )

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Invalid show or track")
      end
    end

    context "when unauthenticated" do
      it "returns a 401 Unauthorized error" do
        post_api(
          "/likes",
          params: { likable_type: "Show", likable_id: show.id }
        )

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Unauthorized")
      end
    end
  end

  describe "DELETE /likes" do
    before do
      show.likes.create!(user: user)
      track.likes.create!(user: user)
    end

    context "when unliking a show" do
      it "removes the like from the show" do
        expect {
          delete_api_authed(
            user,
            "/likes",
            params: { likable_type: "Show", likable_id: show.id }
          )
        }.to change { show.likes.count }.by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when unliking a track" do
      it "removes the like from the track" do
        expect {
          delete_api_authed(
            user,
            "/likes",
            params: { likable_type: "Track", likable_id: track.id }
          )
        }.to change { track.likes.count }.by(-1)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when trying to unlike an invalid object" do
      it "returns a 422 Unprocessable Entity error" do
        delete_api_authed(
          user,
          "/likes",
          params: { likable_type: "Track", likable_id: 0 }
        )

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Invalid show or track")
      end
    end

    context "when the like does not exist" do
      before { track.likes.destroy_all }

      it "returns a 404 Not Found error" do
        delete_api_authed(
          user,
          "/likes",
          params: { likable_type: "Track", likable_id: track.id }
        )

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Like not found")
      end
    end

    context "when unauthenticated" do
      it "returns a 401 Unauthorized error" do
        delete_api(
          "/likes",
          params: { likable_type: "Show", likable_id: show.id }
        )

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Unauthorized")
      end
    end
  end
end
