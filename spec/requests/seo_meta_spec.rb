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

  describe "document head basics" do
    it "declares the page language" do
      get "/"

      expect(response.body).to include(%(<html lang="en">))
    end

    it "puts the charset before the title" do
      get "/"

      expect(response.body.index("<meta charset")).to be < response.body.index("<title>")
    end
  end

  describe "GET an account page" do
    it "renders a noindex robots tag" do
      get "/login"

      expect(response.body).to include(%(<meta name="robots" content="noindex">))
    end
  end

  describe "GET a public page" do
    it "omits the robots tag" do
      get "/top-shows"

      expect(response.body).not_to include(%(<meta name="robots"))
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

  describe "crawlable show content" do
    let!(:venue) { create(:venue, name: "Madison Square Garden", city: "New York", state: "NY") }
    let!(:show) { create(:show, :with_tracks, date: "2024-01-01", venue:) }
    let(:static_content) { Nokogiri::HTML5(response.body).at_css("body > noscript") }

    before { get "/2024-01-01" }

    it "renders outside the React mount node so hydration is unaffected" do
      expect(Nokogiri::HTML5(response.body).at_css("#root noscript")).to be_nil
    end

    it "headlines the show with the numeric date fans search for" do
      expect(static_content.at_css("h1").text).to include("Phish 1/1/24", "Madison Square Garden")
    end

    it "links every track in the setlist" do
      hrefs = static_content.css("ol a").map { |a| a["href"] }
      expect(hrefs).to eq(show.tracks.order(:position).map { |t| "/2024-01-01/#{t.slug}" })
    end

    it "links the venue and year pages" do
      hrefs = static_content.css("a").map { |a| a["href"] }
      expect(hrefs).to include("/venues/#{venue.slug}", "/2024")
    end
  end

  describe "a page without crawlable content" do
    it "renders no noscript fallback" do
      get "/top-shows"

      expect(Nokogiri::HTML5(response.body).at_css("body > noscript")).to be_nil
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
