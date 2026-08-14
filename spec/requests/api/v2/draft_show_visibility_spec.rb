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
