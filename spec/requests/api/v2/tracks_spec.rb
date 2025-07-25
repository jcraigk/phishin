require "rails_helper"

RSpec.describe "API v2 Tracks" do
  let!(:user) { create(:user) }
  let!(:tag) { create(:tag, name: "Classic", priority: 1) }
  let!(:show1) { create(:show, date: "2023-01-01") }
  let!(:show2) { create(:show, date: "2024-01-01") }
  let!(:show3) { create(:show, date: "2025-01-01") }
  let!(:songs) do
    [
      create(:song, title: "Song 1", slug: "song-1"),
      create(:song, title: "Song 2", slug: "song-2"),
      create(:song, title: "Song 3", slug: "song-3")
    ]
  end
  let!(:tracks) do
    [
      create(:track, title: "Track 1", position: 1, duration: 300, likes_count: 10, show: show1,
songs: [ songs[0] ]),
      create(:track, title: "Track 2", position: 2, duration: 240, likes_count: 20, show: show2,
songs: [ songs[1] ]),
      create(:track, title: "Track 3", position: 3, duration: 360, likes_count: 5, show: show3,
songs: [ songs[2] ]),
      create(:track, title: "Track 4", position: 4, duration: 180, likes_count: 15, show: show1,
songs: [ songs[0], songs[1] ])
    ]
  end
  let(:like) { create(:like, user:, likable: tracks[0]) }
  let(:track_tags) do
    [
      create(:track_tag, track: tracks[0], tag:, notes: "A classic track"),
      create(:track_tag, track: tracks[1], tag:, notes: "Another classic track")
    ]
  end

  before do
    like
    track_tags
  end

  describe "GET /tracks" do
    context "with no filters" do
      it "returns paginated tracks sorted by id in ascending order" do
        get_api_authed(user, "/tracks", params: { page: 1, per_page: 2 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:tracks].size).to eq(2)
        expect(json[:total_pages]).to eq(2)

        track_ids = json[:tracks].map { |t| t[:id] }
        expect(track_ids).to eq([ tracks[0].id, tracks[1].id ])

        # Verify exclude_from_stats field is included
        expect(json[:tracks][0][:exclude_from_stats]).to be(false)
        expect(json[:tracks][1][:exclude_from_stats]).to be(false)
      end
    end

    context "with sorting" do
      it "returns tracks sorted by likes_count in descending order" do
        get_api_authed(user, "/tracks", params: { sort: "likes_count:desc", page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        track_ids = json[:tracks].map { |t| t[:id] }

        expect(track_ids).to eq([ tracks[1].id, tracks[3].id, tracks[0].id ])
      end
    end

    context "with tag_slug filter" do
      it "returns tracks filtered by tag_slug" do
        get_api_authed(user, "/tracks", params: { tag_slug: tag.slug })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        track_ids = json[:tracks].map { |t| t[:id] }

        expect(track_ids).to eq([ tracks[0].id, tracks[1].id ])
      end
    end

    context "with song_slug filter" do
      it "returns tracks filtered by song_slug" do
        get_api_authed(user, "/tracks", params: { song_slug: songs[0].slug })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        track_ids = json[:tracks].map { |t| t[:id] }

        expect(track_ids).to eq([ tracks[0].id, tracks[3].id ]) # Tracks associated with song 1
      end
    end

    context "with liked_by_user filter" do
      it "returns only tracks liked by the user when liked_by_user is true" do
        get_api_authed(user, "/tracks", params: { liked_by_user: true })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        track_ids = json[:tracks].map { |t| t[:id] }

        expect(track_ids).to eq([ tracks[0].id ]) # Only track 1 is liked by the user
      end

      it "returns all tracks when liked_by_user is false" do
        get_api_authed(user, "/tracks", params: { liked_by_user: false, page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        track_ids = json[:tracks].map { |t| t[:id] }

        expect(track_ids).to eq([ tracks[0].id, tracks[1].id, tracks[2].id ])
      end
    end

    context "with liked_by_user flag" do
      it "marks liked tracks correctly for the logged-in user" do
        get_api_authed(user, "/tracks", params: { page: 1, per_page: 2 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:tracks][0][:liked_by_user]).to be(true)  # Track 1 is liked
        expect(json[:tracks][1][:liked_by_user]).to be(false) # Track 2 is not liked
      end
    end

    context "with year filter" do
      it "returns tracks from the specified year" do
        get_api_authed(user, "/tracks", params: { year: 2023 })
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:tracks].map { |t| t[:id] }).to contain_exactly(tracks[0].id, tracks[3].id)
      end
    end

    context "with year_range filter" do
      it "returns tracks from the specified year range" do
        get_api_authed(user, "/tracks", params: { year_range: "2023-2024" })
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:tracks].map { |t| t[:id] }).to contain_exactly(tracks[0].id, tracks[1].id, tracks[3].id)
      end
    end

    context "with start_date and end_date filters" do
      it "returns tracks from the specified date range" do
        get_api_authed(user, "/tracks", params: { start_date: "2023-01-01", end_date: "2024-12-31" })
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:tracks].map { |t| t[:id] }).to contain_exactly(tracks[0].id, tracks[1].id, tracks[3].id)
      end

      it "returns tracks from the specified start_date only" do
        get_api_authed(user, "/tracks", params: { start_date: "2024-01-01" })
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:tracks].map { |t| t[:id] }).to contain_exactly(tracks[1].id, tracks[2].id)
      end

      it "returns tracks up to the specified end_date only" do
        get_api_authed(user, "/tracks", params: { end_date: "2023-12-31" })
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:tracks].map { |t| t[:id] }).to contain_exactly(tracks[0].id, tracks[3].id)
      end
    end

    context "with conflicting date filters" do
      it "returns 400 if year and year_range are both present" do
        get_api_authed(user, "/tracks", params: { year: 2023, year_range: "2023-2024" })
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to match(/Cannot specify both year and year_range/)
      end

      it "returns 400 if year and start_date are both present" do
        get_api_authed(user, "/tracks", params: { year: 2023, start_date: "2023-01-01" })
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to match(/Cannot combine year\/year_range with start_date\/end_date/)
      end

      it "returns 400 if year_range and end_date are both present" do
        get_api_authed(user, "/tracks", params: { year_range: "2023-2024", end_date: "2024-12-31" })
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to match(/Cannot combine year\/year_range with start_date\/end_date/)
      end
    end
  end

  describe "GET /tracks/:id" do
    it "returns the specified track with liked_by_user set" do
      track = tracks.first
      get_api_authed(user, "/tracks/#{track.id}")
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:id]).to eq(track.id)
      expect(json[:liked_by_user]).to be(true) # Track 1 is liked by the user
    end

    it "returns a track that is not liked by the user with liked_by_user set to false" do
      track = tracks.second
      get_api_authed(user, "/tracks/#{track.id}")
      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:id]).to eq(track.id)
      expect(json[:liked_by_user]).to be(false) # Track 2 is not liked by the user
    end

    it "returns exclude_from_stats field for tracks" do
      track_with_exclusion = create(:track, title: "Track with exclusion", position: 5, duration: 420, likes_count: 8, show: show2, songs: [ songs[2] ], exclude_from_stats: true)
      track_without_exclusion = tracks.first # Track 1 has default false value

      get_api_authed(user, "/tracks/#{track_with_exclusion.id}")
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:exclude_from_stats]).to be(true)

      get_api_authed(user, "/tracks/#{track_without_exclusion.id}")
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, symbolize_names: true)
      expect(json[:exclude_from_stats]).to be(false)
    end

    it "returns a 404 error if the track does not exist" do
      get_api_authed(user, "/tracks/9999")
      expect(response).to have_http_status(:not_found)
    end
  end
end
