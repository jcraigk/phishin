require "rails_helper"

RSpec.describe "SEO head tags" do
  describe "GET /" do
    it "renders the home title, description and WebSite JSON-LD" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<title>Phish.in - Stream Live Phish Free")
      expect(response.body).to include(%(<meta name="description"))
      expect(response.body).to include(%(application/ld+json))
      expect(response.body).to include(%("@type":"WebSite"))
      expect(response.body).to include(%("@type":"MusicGroup"))
    end
  end

  describe "GET a show page" do
    let!(:venue) { create(:venue, name: "Madison Square Garden", city: "New York", state: "NY") }
    let!(:show) { create(:show, :with_tracks, date: "2024-01-01", venue:) }

    it "renders venue-rich meta, og tags and a MusicEvent graph" do
      get "/2024-01-01"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Phish at #{show.venue_name}, Jan 1, 2024")
      expect(response.body).to include(%(property="og:title"))
      expect(response.body).to include(%(property="og:image"))
      expect(response.body).to include(
        %(<meta property="og:description" content="A complete live audience recording, )
      )
      expect(response.body).to include(%(<meta name="description" content="Stream Phish))
      expect(response.body).to include(%("@type":"MusicEvent"))
      expect(response.body).to include(%("addressLocality":"New York"))
    end
  end

  describe "GET a 404 path" do
    it "responds not_found with a fallback description" do
      get "/9999"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include(%(<meta name="description"))
    end
  end
end
