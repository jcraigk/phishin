require "rails_helper"

RSpec.describe "API v2 Admin Catalog" do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  def token_for(u)
    UserJwtService.call(u)
  end

  def admin_headers
    {
      "X-Auth-Token" => token_for(admin),
      "CONTENT_TYPE" => "application/json"
    }
  end

  def user_headers
    { "X-Auth-Token" => token_for(user), "CONTENT_TYPE" => "application/json" }
  end

  def anon_headers
    { "CONTENT_TYPE" => "application/json" }
  end

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  describe "GET /api/v2/admin/songs" do
    before do
      create(:song, title: "Harry Hood")
      create(:song, title: "Ghost")
    end

    it "returns 401 without a token" do
      get "/api/v2/admin/songs", params: { q: "hood" }, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/songs", params: { q: "hood" }, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "searches songs by partial term" do
      get "/api/v2/admin/songs", params: { q: "hood" }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      titles = json[:songs].map { |s| s[:title] }
      expect(titles).to include("Harry Hood")
      expect(titles).not_to include("Ghost")
    end

    it "returns an empty array when nothing matches" do
      get "/api/v2/admin/songs", params: { q: "zzzznomatch" }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json[:songs]).to eq([])
    end

    it "lists songs alphabetically without a term" do
      get "/api/v2/admin/songs", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json[:songs].map { |s| s[:title] }).to eq([ "Ghost", "Harry Hood" ])
    end
  end

  describe "POST /api/v2/admin/songs" do
    it "returns 401 without a token and creates nothing" do
      expect {
        post "/api/v2/admin/songs", params: { title: "New Jam" }.to_json, headers: anon_headers
      }.not_to change(Song, :count)
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user and creates nothing" do
      expect {
        post "/api/v2/admin/songs", params: { title: "New Jam" }.to_json, headers: user_headers
      }.not_to change(Song, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "creates a song with a generated slug" do
      post "/api/v2/admin/songs", params: { title: "New Jam" }.to_json, headers: admin_headers
      expect(response).to have_http_status(:created)
      song = Song.find_by(title: "New Jam")
      expect(song).to be_present
      expect(song.slug).to eq("new-jam")
      expect(json[:id]).to eq(song.id)
    end

    it "returns 409 on a duplicate title" do
      create(:song, title: "New Jam")
      expect {
        post "/api/v2/admin/songs", params: { title: "New Jam" }.to_json, headers: admin_headers
      }.not_to change(Song, :count)
      expect(response).to have_http_status(:conflict)
      expect(json[:message]).to be_present
    end

    it "returns 409 on a duplicate title differing only by case" do
      create(:song, title: "New Jam")
      expect {
        post "/api/v2/admin/songs", params: { title: "new jam" }.to_json, headers: admin_headers
      }.not_to change(Song, :count)
      expect(response).to have_http_status(:conflict)
    end

    it "returns 422 for a blank title" do
      expect {
        post "/api/v2/admin/songs", params: { title: "   " }.to_json, headers: admin_headers
      }.not_to change(Song, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/v2/admin/venues" do
    before do
      create(:venue, name: "Madison Square Garden", city: "New York", state: "NY", country: "USA")
      create(:venue, name: "The Gorge", city: "George", state: "WA", country: "USA")
    end

    it "returns 401 without a token" do
      get "/api/v2/admin/venues", params: { q: "gorge" }, headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/venues", params: { q: "gorge" }, headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "searches venues by partial name" do
      get "/api/v2/admin/venues", params: { q: "gorge" }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json[:venues].map { |v| v[:name] }).to eq([ "The Gorge" ])
      expect(json[:venues].first).to include(city: "George", state: "WA", country: "USA")
    end

    it "returns an empty array when nothing matches" do
      get "/api/v2/admin/venues", params: { q: "zzzznomatch" }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json[:venues]).to eq([])
    end

    it "lists venues alphabetically without a term" do
      get "/api/v2/admin/venues", headers: admin_headers
      expect(json[:venues].map { |v| v[:name] })
        .to eq([ "Madison Square Garden", "The Gorge" ])
    end
  end

  describe "POST /api/v2/admin/venues" do
    let(:payload) do
      { name: "The Gorge", city: "George", state: "WA", country: "USA" }
    end

    it "returns 401 without a token and creates nothing" do
      expect {
        post "/api/v2/admin/venues", params: payload.to_json, headers: anon_headers
      }.not_to change(Venue, :count)
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user and creates nothing" do
      expect {
        post "/api/v2/admin/venues", params: payload.to_json, headers: user_headers
      }.not_to change(Venue, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "creates a venue with a generated slug" do
      post "/api/v2/admin/venues", params: payload.to_json, headers: admin_headers
      expect(response).to have_http_status(:created)
      venue = Venue.find_by(name: "The Gorge")
      expect(venue).to be_present
      expect(venue.slug).to eq("the-gorge")
      expect(json[:id]).to eq(venue.id)
    end

    it "stores a blank state when none is given" do
      post "/api/v2/admin/venues",
           params: { name: "Bataclan", city: "Paris", country: "France" }.to_json,
           headers: admin_headers
      expect(response).to have_http_status(:created)
      expect(Venue.find_by(name: "Bataclan").state).to eq("")
    end

    it "returns 409 on a duplicate name in the same city" do
      create(:venue, name: "The Gorge", city: "George", state: "WA", country: "USA")
      expect {
        post "/api/v2/admin/venues", params: payload.to_json, headers: admin_headers
      }.not_to change(Venue, :count)
      expect(response).to have_http_status(:conflict)
      expect(json[:message]).to be_present
    end

    it "allows the same name in a different city" do
      create(:venue, name: "The Gorge", city: "Elsewhere", state: "WA", country: "USA")
      post "/api/v2/admin/venues", params: payload.to_json, headers: admin_headers
      expect(response).to have_http_status(:created)
    end

    it "returns 422 for a blank city" do
      expect {
        post "/api/v2/admin/venues",
             params: payload.merge(city: "  ").to_json,
             headers: admin_headers
      }.not_to change(Venue, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/v2/admin/tours" do
    before do
      create(:tour, name: "1994 Fall Tour", starts_on: "1994-09-01", ends_on: "1994-12-01")
      create(:tour, name: "2025 Summer Tour", starts_on: "2025-06-01", ends_on: "2025-09-01")
    end

    it "returns 401 without a token" do
      get "/api/v2/admin/tours", headers: anon_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user" do
      get "/api/v2/admin/tours", headers: user_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "lists tours newest first" do
      get "/api/v2/admin/tours", headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json[:tours].map { |t| t[:name] })
        .to eq([ "2025 Summer Tour", "1994 Fall Tour" ])
      expect(json[:tours].first).to include(starts_on: "2025-06-01", ends_on: "2025-09-01")
    end

    it "searches tours by partial name" do
      get "/api/v2/admin/tours", params: { q: "summer" }, headers: admin_headers
      expect(json[:tours].map { |t| t[:name] }).to eq([ "2025 Summer Tour" ])
    end

    it "returns an empty array when nothing matches" do
      get "/api/v2/admin/tours", params: { q: "zzzznomatch" }, headers: admin_headers
      expect(response).to have_http_status(:ok)
      expect(json[:tours]).to eq([])
    end
  end

  describe "POST /api/v2/admin/tours" do
    let(:payload) do
      { name: "2025 Summer Tour", starts_on: "2025-06-01", ends_on: "2025-09-01" }
    end

    it "returns 401 without a token and creates nothing" do
      expect {
        post "/api/v2/admin/tours", params: payload.to_json, headers: anon_headers
      }.not_to change(Tour, :count)
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for a non-admin user and creates nothing" do
      expect {
        post "/api/v2/admin/tours", params: payload.to_json, headers: user_headers
      }.not_to change(Tour, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "creates a tour with a generated slug" do
      post "/api/v2/admin/tours", params: payload.to_json, headers: admin_headers
      expect(response).to have_http_status(:created)
      tour = Tour.find_by(name: "2025 Summer Tour")
      expect(tour).to be_present
      expect(tour.slug).to eq("2025-summer-tour")
      expect(json).to include(id: tour.id, starts_on: "2025-06-01", ends_on: "2025-09-01")
    end

    it "returns 409 on a duplicate name" do
      create(:tour, name: "2025 Summer Tour", starts_on: "2024-06-01", ends_on: "2024-09-01")
      expect {
        post "/api/v2/admin/tours", params: payload.to_json, headers: admin_headers
      }.not_to change(Tour, :count)
      expect(response).to have_http_status(:conflict)
      expect(json[:message]).to be_present
    end

    it "returns 409 when the start date is already taken" do
      create(:tour, name: "Other Tour", starts_on: "2025-06-01", ends_on: "2025-07-01")
      expect {
        post "/api/v2/admin/tours", params: payload.to_json, headers: admin_headers
      }.not_to change(Tour, :count)
      expect(response).to have_http_status(:conflict)
    end

    it "returns 422 when ends_on precedes starts_on" do
      expect {
        post "/api/v2/admin/tours",
             params: payload.merge(starts_on: "2025-09-01", ends_on: "2025-06-01").to_json,
             headers: admin_headers
      }.not_to change(Tour, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 400 for an unparseable date" do
      expect {
        post "/api/v2/admin/tours",
             params: payload.merge(starts_on: "not-a-date").to_json,
             headers: admin_headers
      }.not_to change(Tour, :count)
      expect(response).to have_http_status(:bad_request)
    end
  end
end
