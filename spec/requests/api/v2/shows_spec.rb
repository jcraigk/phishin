require "rails_helper"

RSpec.describe "API v2 Shows", type: :request do
  let!(:user) { create(:user) }
  let!(:venue) { create(:venue, name: "Madison Square Garden") }
  let!(:show1) { create(:show, date: "2023-01-01", venue:) }
  let!(:show2) { create(:show, date: "2024-01-01", venue:) }
  let!(:show3) { create(:show, date: "2025-01-01", venue:) }
  let!(:show4) { create(:show, date: "2021-01-01", venue:) }
  let!(:tag) { create(:tag, name: "Classic", priority: 1) }

  let!(:show_tags) do
    [
      create(:show_tag, show: show1, tag:, notes: "A classic show"),
      create(:show_tag, show: show2, tag:, notes: "Another classic show")
    ]
  end

  let!(:like) { create(:like, user:, likable: show1) }

  describe "GET /shows" do
    context "with no filters" do
      it "returns paginated shows sorted by date:desc by default" do
        get_api_authed(user, "/shows", params: { page: 1, per_page: 2 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:shows].size).to eq(2)
        expect(json[:total_pages]).to eq(2)

        show_ids = json[:shows].map { |s| s[:id] }
        expect(show_ids).to eq([show3.id, show2.id]) # Sorted by date:desc
      end
    end

    context "with sorting" do
      it "returns shows sorted by likes_count in descending order" do
        get_api_authed(user, "/shows", params: { sort: "likes_count:desc", page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids.first).to eq(show1.id)
      end
    end

    context "with tag_slug filter" do
      it "returns shows filtered by tag_slug" do
        get_api_authed(user, "/shows", params: { tag_slug: tag.slug })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([show2.id, show1.id]) # Shows associated with the "Classic" tag
      end
    end

    context "with liked_by_user" do
      it "marks liked shows correctly for the logged-in user" do
        get_api_authed(user, "/shows", params: { page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        # We expect shows to be returned in date:desc order
        expect(show_ids).to eq([show3.id, show2.id, show1.id]) # Date descending order

        # Show 1 is liked, so the third item (show1) should be liked_by_user
        expect(json[:shows][2][:liked_by_user]).to eq(true)  # Show 1 is liked
        expect(json[:shows][0][:liked_by_user]).to eq(false) # Show 3 is not liked
      end
    end
  end

  describe "GET /shows/:id" do
    it "returns the specified show with liked_by_user set" do
      show = show1
      get_api_authed(user, "/shows/#{show.id}")
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:id]).to eq(show.id)
      expect(json[:liked_by_user]).to eq(true) # Show 1 is liked by the user
    end

    it "returns a show that is not liked by the user with liked_by_user set to false" do
      show = show2
      get_api_authed(user, "/shows/#{show.id}")
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:id]).to eq(show.id)
      expect(json[:liked_by_user]).to eq(false) # Show 2 is not liked by the user
    end

    it "returns a 404 error if the show does not exist" do
      get_api_authed(user, "/shows/9999")
      expect(response).to have_http_status(:not_found)
    end
  end
end
