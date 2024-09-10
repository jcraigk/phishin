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
        expect(show_ids).to eq([ show3.id, show2.id ]) # Sorted by date:desc
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

        expect(show_ids).to eq([ show2.id, show1.id ]) # Shows associated with the "Classic" tag
      end
    end

    context "with liked_by_user set to true" do
      it "returns only shows liked by the current user" do
        get_api_authed(user, "/shows", params: { liked_by_user: true, page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show1.id ]) # Only show1 is liked by the user
      end
    end

    context "with liked_by_user set to false" do
      it "returns all shows regardless of user likes" do
        get_api_authed(user, "/shows", params: { liked_by_user: false, page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show3.id, show2.id, show1.id ]) # All shows in date:desc order
      end
    end
  end
end
