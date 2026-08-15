require "rails_helper"

RSpec.describe "Draft show visibility" do
  include ApiHelper

  let!(:venue) { create(:venue) }
  let!(:published_show) { create(:show, date: "2024-01-01", venue:) }
  let!(:draft_show) { create(:show, date: "2024-01-02", venue:, published: false) }
  let!(:song) { create(:song, title: "Chalk Dust Torture") }
  let!(:published_track) do
    create(:track, show: published_show, position: 1, songs: [ song ], slug: "cdt-1")
  end
  let!(:draft_track) do
    create(:track, show: draft_show, position: 1, songs: [ song ], slug: "cdt-2")
  end

  it "excludes drafts from the v2 shows index" do
    get "/api/v2/shows"
    dates = JSON.parse(response.body)["shows"].map { |s| s["date"] }
    expect(dates).to include("2024-01-01")
    expect(dates).not_to include("2024-01-02")
  end

  it "404s a draft show fetched by date" do
    get "/api/v2/shows/2024-01-02"
    expect(response).to have_http_status(:not_found)
  end

  it "excludes draft tracks from the v2 tracks index" do
    get "/api/v2/tracks"
    ids = JSON.parse(response.body)["tracks"].map { |t| t["slug"] }
    expect(ids).not_to include("cdt-2")
  end

  it "excludes drafts from the v1 shows index" do
    get "/api/v1/shows", headers: auth_header
    body = response.body
    expect(body).to include("2024-01-01")
    expect(body).not_to include("2024-01-02")
  end

  it "404s a draft show in v1 while serving a published one" do
    headers = auth_header
    get("/api/v1/shows/2024-01-01", headers:)
    expect(response).to have_http_status(:ok)
    get("/api/v1/shows/2024-01-02", headers:)
    expect(response).to have_http_status(:not_found)
  end

  it "blocks downloads of draft tracks" do
    get "/download-track/#{draft_track.id}"
    expect(response).to have_http_status(:not_found)
  end

  it "excludes drafts from the RSS feed" do
    get "/feeds/rss"
    expect(response.body).not_to include("2024-01-02")
  end

  it "excludes drafts from the sitemap" do
    get "/sitemap.xml"
    expect(response.body).not_to include("2024-01-02")
  end

  it "excludes a draft show from MCP list_shows output" do
    result = Tools::ListShows.fetch_shows(2024, nil, nil, nil, nil, "date", "asc", 50)
    dates = result[:shows].map { |s| s[:date] }
    expect(dates).to include("2024-01-01")
    expect(dates).not_to include("2024-01-02")
  end

  it "excludes a draft show from MCP get_show output" do
    response = Tools::GetShow.call(date: "2024-01-02")
    expect(response.error?).to be true
  end

  it "excludes a draft show from the markdown view of its own date path" do
    get "/2024-01-02", headers: { "Accept" => "text/markdown" }
    expect(response.body).not_to include("Chalk Dust Torture")
    expect(response.body).to include("Not found")
  end

  it "serves the markdown view of a published show normally" do
    get "/2024-01-01", headers: { "Accept" => "text/markdown" }
    expect(response.body).to include("2024-01-01".tr("-", "-"))
  end

  it "renders not-found meta tags for a draft show's date path" do
    meta = MetaTagService.call("/2024-01-02")
    expect(meta).to eq(MetaTagService.call("/1900-01-01"))
    expect(meta[:status]).to eq(:not_found)
    expect(meta[:title]).not_to include(venue.name)
  end

  it "renders normal meta tags for a published show's date path" do
    meta = MetaTagService.call("/2024-01-01")
    expect(meta[:status]).to eq(:ok)
    expect(meta[:title]).to include(venue.name)
  end

  it "renders not-found meta tags for a draft show's track path" do
    meta = MetaTagService.call("/2024-01-02/cdt-2")
    expect(meta[:status]).to eq(:not_found)
    expect(meta[:title]).not_to include("Chalk Dust Torture")
  end

  it "excludes draft-only years from year meta tags" do
    create(:show, date: "2029-05-05", venue:, published: false)
    expect(MetaTagService.call("/2029")[:status]).to eq(:not_found)
    expect(MetaTagService.call("/2029-2030")[:status]).to eq(:not_found)
    expect(MetaTagService.call("/2024")[:status]).to eq(:ok)
  end

  it "emits no structured data for a draft show's date path" do
    expect(StructuredDataService.call("/2024-01-02")).to eq([])
    expect(StructuredDataService.call("/2024-01-02/cdt-2")).to eq([])
  end

  it "emits a MusicEvent graph for a published show's date path" do
    graphs = StructuredDataService.call("/2024-01-01")
    expect(graphs.first[:"@type"]).to eq("MusicEvent")
    expect(graphs.first[:name]).to include(venue.name)
  end

  describe "stats MCP tool" do
    let!(:stats_venue) { create(:venue, state: "ZZ", country: "USA") }
    let!(:stats_draft_show) do
      create(:show, date: "2024-06-01", venue: stats_venue, published: false,
                    performance_gap_value: 1)
    end

    before do
      create(:track, show: stats_draft_show, position: 1, set: "1", songs: [ song ],
                     slug: "cdt-3", exclude_from_stats: false)
    end

    it "excludes draft shows from geographic state frequency counts" do
      result = Tools::Stats.fetch_stats("geographic", { geo_type: "state_frequency" })
      states = result[:states].map { |s| s[:state] }
      expect(states).not_to include("ZZ")
    end

    it "excludes draft-show tracks from song frequency counts" do
      result = Tools::Stats.fetch_stats("song_frequency", { state: "ZZ" })
      expect(result[:songs]).to be_empty
    end
  end

  describe "request_album_zip" do
    it "404s a draft show's date" do
      post "/api/v2/shows/request_album_zip", params: { date: "2024-01-02" }
      expect(response).to have_http_status(:not_found)
    end

    it "does not 404 a published show's date" do
      post "/api/v2/shows/request_album_zip", params: { date: "2024-01-01" }
      expect(response).not_to have_http_status(:not_found)
    end
  end

  describe "playlist markdown" do
    before do
      playlist = create(:playlist, slug: "mixed-playlist")
      playlist.playlist_tracks.destroy_all
      create(:playlist_track, playlist:, track: published_track, position: 1)
      create(:playlist_track, playlist:, track: draft_track, position: 2)
    end

    it "omits draft-show tracks while rendering published ones" do
      body = MarkdownViewService.call("/play/mixed-playlist")
      expect(body).to include(published_track.title)
      expect(body).not_to include("Jan 2, 2024")
    end
  end

  describe "admin preview" do
    let(:admin) { create(:user, :admin) }
    let(:non_admin) { create(:user) }
    let(:admin_header) { { "X-Auth-Token" => UserJwtService.call(admin) } }
    let(:non_admin_header) { { "X-Auth-Token" => UserJwtService.call(non_admin) } }

    it "allows an admin to fetch a draft by date" do
      get "/api/v2/shows/2024-01-02", headers: admin_header
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["date"]).to eq("2024-01-02")
    end

    it "404s a draft by date for an anonymous request" do
      get "/api/v2/shows/2024-01-02"
      expect(response).to have_http_status(:not_found)
    end

    it "404s a draft by date for a logged-in non-admin" do
      get "/api/v2/shows/2024-01-02", headers: non_admin_header
      expect(response).to have_http_status(:not_found)
    end

    it "does not cache the admin preview for later anonymous requests" do
      get "/api/v2/shows/2024-01-02", headers: admin_header
      expect(response).to have_http_status(:ok)
      get "/api/v2/shows/2024-01-02"
      expect(response).to have_http_status(:not_found)
    end

    it "still serves a published show to an admin" do
      get "/api/v2/shows/2024-01-01", headers: admin_header
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["date"]).to eq("2024-01-01")
    end

    it "excludes drafts from the v2 shows index for an admin" do
      get "/api/v2/shows", headers: admin_header
      dates = JSON.parse(response.body)["shows"].map { |s| s["date"] }
      expect(dates).to include("2024-01-01")
      expect(dates).not_to include("2024-01-02")
    end

    it "excludes draft tracks from the v2 tracks index for an admin" do
      get "/api/v2/tracks", headers: admin_header
      slugs = JSON.parse(response.body)["tracks"].map { |t| t["slug"] }
      expect(slugs).not_to include("cdt-2")
    end

    it "excludes drafts from the v1 shows index for an admin" do
      get "/api/v1/shows", headers: auth_header.merge(admin_header)
      expect(response.body).to include("2024-01-01")
      expect(response.body).not_to include("2024-01-02")
    end

    it "404s a draft in v1 for an admin" do
      get "/api/v1/shows/2024-01-02", headers: auth_header.merge(admin_header)
      expect(response).to have_http_status(:not_found)
    end

    it "excludes drafts from the sitemap for an admin" do
      get "/sitemap.xml", headers: admin_header
      expect(response.body).not_to include("2024-01-02")
    end

    it "excludes a draft from the markdown view for an admin" do
      get "/2024-01-02", headers: admin_header.merge("Accept" => "text/markdown")
      expect(response.body).not_to include("Chalk Dust Torture")
      expect(response.body).to include("Not found")
    end

    it "404s a draft album zip request for an admin" do
      post "/api/v2/shows/request_album_zip", params: { date: "2024-01-02" }, headers: admin_header
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "chronological track navigation" do
    let!(:early_show) { create(:show, date: "2023-01-01", venue:) }
    let!(:early_track) do
      create(:track, show: early_show, position: 1, set: "1", audio_status: "complete")
    end
    let!(:late_draft_show) { create(:show, date: "2025-01-01", venue:, published: false) }
    let!(:late_draft_track) do
      create(:track, show: late_draft_show, position: 1, set: "1", audio_status: "complete")
    end

    it "never navigates into a draft show" do
      expect(ChronologicalTrackNavigator.call(published_track, direction: :next))
        .not_to eq(late_draft_track)
      expect(ChronologicalTrackNavigator.call(early_track, direction: :prev))
        .not_to eq(late_draft_track)
    end

    it "excludes draft shows from adjacent show lookups" do
      expect(ChronologicalTrackNavigator.adjacent_show(published_show, direction: :next)).to be_nil
      expect(ChronologicalTrackNavigator.adjacent_show(published_show, direction: :prev))
        .to eq(early_show)
    end

    it "excludes draft tracks from first and last track in library" do
      expect(ChronologicalTrackNavigator.first_track).to eq(early_track)
      expect(ChronologicalTrackNavigator.last_track).not_to eq(late_draft_track)
      expect(ChronologicalTrackNavigator.last_track.show).to eq(published_show)
    end
  end
end
