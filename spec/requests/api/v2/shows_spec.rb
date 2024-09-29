require "rails_helper"

RSpec.describe "API v2 Shows" do
  let!(:user) { create(:user) }
  let!(:venue) { create(:venue, name: "Madison Square Garden") }
  let!(:known_dates) do
    [
      create(:known_date, date: "2022-12-29"),
      create(:known_date, date: "2022-12-30"),
      create(:known_date, date: "2022-12-31"),
      create(:known_date, date: "2023-01-01"),
      create(:known_date, date: "2023-01-02"),
      create(:known_date, date: "2023-01-03"),
      create(:known_date, date: "2023-01-04"),
      create(:known_date, date: "2023-01-05")
    ]
  end
  let!(:previous_show) { create(:show, date: "2022-12-30", venue:, likes_count: 0) }
  let!(:next_show) { create(:show, date: "2023-01-05", venue:, likes_count: 25) }
  let!(:show1) { create(:show, date: "2023-01-01", venue:, likes_count: 50) }
  let!(:song) { create(:song, title: "Tweezer") }
  let!(:tracks) do
    [
      create(:track, show: show1, position: 1, songs: [ song ], slug: 'tweezer-1'),
      create(:track, show: show1, position: 5, songs: [ song ], slug: 'tweezer-2'),
      create(:track, show: show1, position: 10, songs: [ song ], slug: 'tweezer-3'),
      create(:track, show: previous_show, position: 1, songs: [ song ], slug: 'tweezer-4'),
      create(:track, show: next_show, position: 1, songs: [ song ], slug: 'tweezer-5')
    ]
  end

  describe "GET /shows/:date" do
    before do
      [ show1, previous_show, next_show ].each do |show|
        GapService.call(show)
      end
    end

    it "returns gaps for a song that appears multiple times in the show" do
      get_api_authed(user, "/shows/2023-01-01")

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      tracks = json[:tracks]

      expect(tracks.count { |t| t[:songs].any? { |s| s[:title] == "Tweezer" } }).to eq(3)

      tweezer_tracks = tracks.select { |t| t[:songs].any? { |s| s[:title] == "Tweezer" } }

      expect(tweezer_tracks[0][:songs].first[:previous_performance_gap]).to eq(2)
      expect(tweezer_tracks[0][:songs].first[:previous_performance_slug]).to \
        eq("2022-12-30/tweezer-4")
      expect(tweezer_tracks[0][:songs].first[:next_performance_gap]).to eq(0)

      expect(tweezer_tracks[1][:songs].first[:previous_performance_gap]).to eq(0)
      expect(tweezer_tracks[1][:songs].first[:previous_performance_slug]).to \
        eq("2023-01-01/tweezer-1")
      expect(tweezer_tracks[1][:songs].first[:next_performance_gap]).to eq(0)

      expect(tweezer_tracks[2][:songs].first[:previous_performance_gap]).to eq(0)
      expect(tweezer_tracks[2][:songs].first[:previous_performance_slug]).to \
        eq("2023-01-01/tweezer-2")
      expect(tweezer_tracks[2][:songs].first[:next_performance_gap]).to eq(4)
      expect(tweezer_tracks[2][:songs].first[:next_performance_slug]).to eq("2023-01-05/tweezer-5")
    end
  end

  describe "GET /shows" do
    context "with no filters" do
      it "returns paginated shows sorted by date:desc by default" do
        get_api_authed(user, "/shows", params: { page: 1, per_page: 2 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:shows].size).to eq(2)
        expect(json[:total_pages]).to eq(2)

        show_ids = json[:shows].map { |s| s[:id] }
        expect(show_ids).to eq([ next_show.id, show1.id ])
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
      let!(:tag) { create(:tag, name: "Classic", priority: 1) }
      let!(:show_tag) { create(:show_tag, show: show1, tag:, notes: "A classic show") }

      it "returns shows filtered by tag_slug" do
        get_api_authed(user, "/shows", params: { tag_slug: tag.slug })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show1.id ])
      end
    end

    context "with liked_by_user set to true" do
      let!(:like) { create(:like, user:, likable: show1) }

      it "returns only shows liked by the current user" do
        get_api_authed(user, "/shows", params: { liked_by_user: true, page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show1.id ])
      end
    end

    context "with liked_by_user set to false" do
      it "returns all shows regardless of user likes" do
        get_api_authed(user, "/shows", params: { liked_by_user: false, page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ next_show.id, show1.id, previous_show.id ])
      end
    end
  end
end
