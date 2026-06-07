require "rails_helper"

RSpec.describe MetaTagService do
  subject(:service) { described_class.call(path) }

  let(:title_suffix) { " - #{App.app_name}" }

  context "when the path is root" do
    let(:path) { "/" }

    it "returns a keyword-rich title and description" do
      expect(service[:title]).to eq(
        "Phish.in - Stream Live Phish Free | Audience Recordings & Setlists"
      )
      expect(service[:description]).to include("live Phish")
      expect(service[:description]).to include("audience recording")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a hardcoded title" do
    let(:path) { "/login" }

    it "returns the correct title and a description for /login" do
      expect(service[:title]).to eq("Login#{title_suffix}")
      expect(service[:description]).to be_present
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a hardcoded title with a custom description" do
    let(:path) { "/top-shows" }

    it "returns an SEO title override and tailored description" do
      expect(service[:title]).to eq("Best Phish Shows#{title_suffix}")
      expect(service[:description]).to include("highest-rated")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a resource index" do
    let(:path) { "/songs" }

    it "returns a keyword-rich title and description for /songs" do
      expect(service[:title]).to eq("Phish Songs#{title_suffix}")
      expect(service[:description]).to include("every song")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is the venues index" do
    let(:path) { "/venues" }

    it "returns a keyword-rich title and description for /venues" do
      expect(service[:title]).to eq("Phish Venues#{title_suffix}")
      expect(service[:description]).to be_present
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a playlist with a valid slug" do
    let!(:playlist) { create(:playlist) }
    let(:path) { "/play/#{playlist.slug}" }

    it "returns the playlist title, description and og tags" do
      expect(service[:title]).to eq("Listen to #{playlist.name}#{title_suffix}")
      expect(service[:description]).to include(playlist.name)
      expect(service[:og][:title]).to eq("Listen to #{playlist.name}")
      expect(service[:og][:audio]).to eq(playlist.tracks.first.mp3_url)
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a playlist with an invalid slug" do
    let(:path) { "/play/non-existent-slug" }

    it "returns 404 not found" do
      expect(service[:title]).to eq("404 - Phish.in")
      expect(service[:status]).to eq(:not_found)
    end
  end

  context "when the path is a show date without a slug" do
    let!(:venue) { create(:venue, name: "Madison Square Garden", city: "New York", state: "NY") }
    let!(:show) { create(:show, date: "2024-01-01", venue:) }
    let(:path) { "/2024-01-01" }

    it "returns a venue-rich title, description and og tags" do
      expect(service[:title]).to eq("Phish at #{show.venue_name}, Jan 1, 2024#{title_suffix}")
      expect(service[:description]).to include(show.venue_name)
      expect(service[:description]).to include("January 1, 2024")
      expect(service[:og][:title]).to eq(
        "Listen to Phish perform at #{show.venue_name} on January 1, 2024"
      )
      expect(service[:og][:image]).to eq(show.cover_art_urls[:medium])
      expect(service[:og][:description]).to be_present
      expect(service[:og][:description]).not_to include(show.venue_name)
      expect(service[:og][:description]).not_to include("2024")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a show date with a valid track slug" do
    let!(:show) { create(:show, date: "2024-01-01") }
    let!(:track) { create(:track, show:) }
    let(:path) { "/2024-01-01/#{track.slug}" }

    it "returns the track title, description and og tags" do
      expect(service[:title]).to eq("#{track.title} by Phish - Jan 1, 2024#{title_suffix}")
      expect(service[:description]).to include(track.title)
      expect(service[:description]).to include("January 1, 2024")
      expect(service[:og][:title]).to eq(
        "Listen to Phish perform #{track.title} on January 1, 2024"
      )
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a show date with an invalid track slug" do
    let(:show) { create(:show, date: "2024-01-01") }
    let(:path) { "/2024-01-01/invalid-slug" }

    it "returns the show title without track details and status ok" do
      show
      expect(service[:title]).to eq("Phish at #{show.venue_name}, Jan 1, 2024#{title_suffix}")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is for a year with no shows" do
    let(:path) { "/2025" }

    it "returns 404 not found" do
      expect(service[:title]).to eq("404 - Phish.in")
      expect(service[:status]).to eq(:not_found)
    end
  end

  context "when the path is for a year with shows" do
    let(:show) { create(:show, date: "2023-05-01") }
    let(:path) { "/2023" }

    it "returns a keyword-rich year title and description" do
      show
      expect(service[:title]).to eq("Phish 2023#{title_suffix}")
      expect(service[:description]).to include("2023")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is for a year range with shows" do
    let(:show) { create(:show, date: "2023-05-01") }
    let(:path) { "/2022-2023" }

    it "returns a keyword-rich year-range title" do
      show
      expect(service[:title]).to eq("Phish 2022-2023#{title_suffix}")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is for a year range with no shows" do
    let(:path) { "/2022-2023" }

    it "returns 404 not found" do
      expect(service[:title]).to eq("404 - Phish.in")
      expect(service[:status]).to eq(:not_found)
    end
  end

  context "when the path is a show tag with a valid slug" do
    let!(:tag) { create(:tag) }
    let(:path) { "/show-tags/#{tag.slug}" }

    it "returns the tag title and description for shows" do
      expect(service[:title]).to eq("#{tag.name} - Shows#{title_suffix}")
      expect(service[:description]).to include(tag.name)
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a show tag with an invalid slug" do
    let(:path) { "/show-tags/invalid-slug" }

    it "returns 404 not found" do
      expect(service[:title]).to eq("404 - Phish.in")
      expect(service[:status]).to eq(:not_found)
    end
  end

  context "when the path is a track tag with a valid slug" do
    let!(:tag) { create(:tag) }
    let(:path) { "/track-tags/#{tag.slug}" }

    it "returns the tag title for tracks" do
      expect(service[:title]).to eq("#{tag.name} - Tracks#{title_suffix}")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a track tag with an invalid slug" do
    let(:path) { "/track-tags/invalid-slug" }

    it "returns 404 not found" do
      expect(service[:title]).to eq("404 - Phish.in")
      expect(service[:status]).to eq(:not_found)
    end
  end

  context "when the path is a song with a valid slug" do
    let!(:song) { create(:song) }
    let(:path) { "/songs/#{song.slug}" }

    it "returns the song title, description and og tags" do
      expect(service[:title]).to eq("#{song.name} by Phish#{title_suffix}")
      expect(service[:description]).to include(song.name)
      expect(service[:og][:title]).to eq("Listen to Phish perform #{song.name}")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a song with an invalid slug" do
    let(:path) { "/songs/invalid-slug" }

    it "returns 404 not found" do
      expect(service[:title]).to eq("404 - Phish.in")
      expect(service[:status]).to eq(:not_found)
    end
  end

  context "when the path is a venue with a valid slug" do
    let!(:venue) { create(:venue) }
    let(:path) { "/venues/#{venue.slug}" }

    it "returns the venue title, description and og tags" do
      expect(service[:title]).to eq("Phish at #{venue.name}#{title_suffix}")
      expect(service[:description]).to include(venue.name)
      expect(service[:og][:title]).to eq("Listen to Phish perform at #{venue.name}")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a venue with an invalid slug" do
    let(:path) { "/venues/invalid-slug" }

    it "returns 404 not found" do
      expect(service[:title]).to eq("404 - Phish.in")
      expect(service[:status]).to eq(:not_found)
    end
  end
end
