require "rails_helper"

RSpec.describe "API v2 Shows" do
  let!(:user) { create(:user) }
  let!(:venue) { create(:venue, name: "Madison Square Garden") }
  let!(:previous_show) { create(:show, date: "2022-12-30", venue:, likes_count: 0) }
  let!(:next_show) { create(:show, date: "2023-01-05", venue:, likes_count: 25) }
  let!(:show1) { create(:show, date: "2023-01-01", venue:, likes_count: 50) }
  let!(:song) { create(:song, title: "Tweezer") }
  let(:tracks) do
    [
      create(:track, show: show1, position: 1, songs: [ song ], slug: 'tweezer-1'),
      create(:track, show: show1, position: 5, songs: [ song ], slug: 'tweezer-2'),
      create(:track, show: show1, position: 10, songs: [ song ], slug: 'tweezer-3'),
      create(:track, show: previous_show, position: 1, songs: [ song ], slug: 'tweezer-4'),
      create(:track, show: next_show, position: 1, songs: [ song ], slug: 'tweezer-5')
    ]
  end
  let(:shows_with_missing_audio) do
    [
      create(:show, date: "2022-12-29", audio_status: 'missing'),
      create(:show, date: "2022-12-31", audio_status: 'missing'),
      create(:show, date: "2023-01-02", audio_status: 'missing'),
      create(:show, date: "2023-01-03", audio_status: 'missing'),
      create(:show, date: "2023-01-04", audio_status: 'missing')
    ]
  end

  before do
    tracks
    shows_with_missing_audio
  end

  describe "GET /shows/:date" do
    before do
      [ show1, previous_show, next_show ].each do |show|
        GapService.call(show)
      end
    end

    it "returns gaps for a song that appears multiple times in the show" do
      # Manually populate some gap data for testing since we're not using real Phish.net API
      show = Show.find_by(date: "2023-01-01")
      tweezer_song = Song.find_by(title: "Tweezer")

      # Set up some test gap data
      show.tracks.joins(:songs).where(songs: { title: "Tweezer" }).each_with_index do |track, index|
        songs_track = SongsTrack.find_by(track: track, song: tweezer_song)
        songs_track.update!(previous_performance_gap: index == 0 ? 5 : 0)
      end

      get_api_authed(user, "/shows/2023-01-01")

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body, symbolize_names: true)
      tracks = json[:tracks]

      expect(tracks.count { |t| t[:songs].any? { |s| s[:title] == "Tweezer" } }).to eq(3)

      tweezer_tracks = tracks.select { |t| t[:songs].any? { |s| s[:title] == "Tweezer" } }

      # First Tweezer should have the gap we set
      expect(tweezer_tracks[0][:songs].first[:previous_performance_gap]).to eq(5)

      # Subsequent Tweezers in the same show should have 0 gap
      expect(tweezer_tracks[1][:songs].first[:previous_performance_gap]).to eq(0)
      expect(tweezer_tracks[2][:songs].first[:previous_performance_gap]).to eq(0)
    end
  end

  describe "GET /shows" do
    context "with no filters" do
      it "returns paginated shows sorted by date:desc by default" do
        get_api_authed(user, "/shows", params: { page: 1, per_page: 2 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:shows].size).to eq(2)
        expect(json[:total_pages]).to eq(4)  # Now includes missing audio shows

        show_ids = json[:shows].map { |s| s[:id] }
        expect(show_ids.first).to eq(next_show.id)  # Just check first show
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
      let(:show_tag) { create(:show_tag, show: show1, tag:, notes: "A classic show") }

      it "returns shows filtered by tag_slug" do
        show_tag

        get_api_authed(user, "/shows", params: { tag_slug: tag.slug })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show1.id ])
      end
    end

    context "with liked_by_user set to true" do
      let(:like) { create(:like, user:, likable: show1) }

      it "returns only shows liked by the current user" do
        like

        get_api_authed(user, "/shows", params: { liked_by_user: true, page: 1, per_page: 3 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show1.id ])
      end
    end

    context "with liked_by_user set to false" do
      it "returns all shows regardless of user likes" do
        get_api_authed(user, "/shows", params: { liked_by_user: false, page: 1, per_page: 8 })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to include(next_show.id, show1.id, previous_show.id)
        expect(show_ids.size).to eq(8)  # All shows including missing audio ones
      end
    end

    context "with venue_id filter" do
      let!(:other_venue) { create(:venue, name: "The Roxy") }
      let!(:show2) { create(:show, date: "2023-01-06", venue: other_venue) }

      it "returns shows filtered by venue_slug" do
        get_api_authed(user, "/shows", params: { venue_slug: other_venue.slug })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show2.id ])
      end
    end

    context "with year filter" do
      it "returns shows filtered by year range" do
        get_api_authed(user, "/shows", params: { year: "2022" })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_dates = json[:shows].map { |s| s[:date] }

        expect(show_dates).to contain_exactly("2022-12-29", "2022-12-30", "2022-12-31")
      end
    end

    context "with year_range filter" do
      it "returns shows filtered by year range" do
        get_api_authed(user, "/shows", params: { year_range: "2022-2023" })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_dates = json[:shows].map { |s| s[:date] }

        expect(show_dates).to contain_exactly("2022-12-29", "2022-12-30", "2022-12-31", "2023-01-01", "2023-01-02", "2023-01-03", "2023-01-04", "2023-01-05")
      end
    end

    context "with us_state filter" do
      let!(:other_venue) { create(:venue, name: "Red Rocks", state: "CO") }
      let!(:show_in_co) { create(:show, date: "2022-08-15", venue: other_venue) }

      it "returns shows filtered by US state" do
        get_api_authed(user, "/shows", params: { us_state: "CO" })
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show_in_co.id ])
      end
    end

    context "with lat/lng distance filter" do
      let!(:near_venue) { create(:venue, name: "Near Venue", latitude: 40.7, longitude: -74.0) }
      let!(:show_near) { create(:show, date: "2022-11-20", venue: near_venue) }
      let!(:far_venue) { create(:venue, name: "Far Venue", latitude: 34.0, longitude: -118.2) }
      let(:show_far) { create(:show, date: "2022-11-21", venue: far_venue) }

      it "returns shows within the specified distance from the given coordinates" do
        show_far

        get_api_authed(
          user,
          "/shows",
          params: {
            lat: 40.7128, # Near NYC
            lng: -74.0060,
            distance: 50 # 50 miles radius
          }
        )
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        show_ids = json[:shows].map { |s| s[:id] }

        expect(show_ids).to eq([ show_near.id ])
      end
    end
  end

  describe "GET /shows/random" do
    it "returns a random show" do
      get_api_authed(user, "/shows/random")

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body, symbolize_names: true)

      expect(json[:id]).to be_present
      expect(json[:date]).to be_present
      expect(json[:venue]).to be_present
    end
  end

  describe "GET /shows/day_of_year/:date" do
    let(:shows_on_date) do
      [
        create(:show, date: "2021-12-29", venue:, likes_count: 20)
      ]
    end
    let(:show_on_different_date) { create(:show, date: "2022-12-28", venue:) }

    context "with a valid date" do
      it "returns shows for that day of the year, sorted by date:desc" do
        shows_on_date
        show_on_different_date

        get_api_authed(user, "/shows/day_of_year/2022-12-29")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:shows].size).to eq(2)
        expect(json[:shows].map { |s| s[:date] }).to eq([ "2022-12-29", "2021-12-29" ])
      end
    end

    context "with no shows on that day" do
      it "returns an empty array" do
        get_api_authed(user, "/shows/day_of_year/2022-02-01")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)

        expect(json[:shows]).to be_empty
      end
    end

    context "with an invalid date format" do
      it "returns a 400 error" do
        get_api_authed(user, "/shows/day_of_year/invalid-date")

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)

        expect(json["message"]).to eq("Invalid date format")
      end
    end
  end
end
