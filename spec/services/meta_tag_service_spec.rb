require "rails_helper"

RSpec.describe MetaTagService do
  subject(:service) { described_class.call(path) }

  let(:title_suffix) { " - #{App.app_name}" }

  context "when the path is root" do
    let(:path) { "/" }

    it "returns the base title" do
      expect(service[:title]).to eq(App.app_name)
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a hardcoded title" do
    let(:path) { "/login" }

    it "returns the correct title for /login" do
      expect(service[:title]).to eq("Login#{title_suffix}")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a resource index" do
    let(:path) { "/songs" }

    it "returns the correct title for /songs" do
      expect(service[:title]).to eq("Songs#{title_suffix}")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a playlist with a valid slug" do
    let!(:playlist) { create(:playlist) }
    let(:path) { "/play/#{playlist.slug}" }

    it "returns the playlist title and og tags" do
      expect(service[:title]).to eq("Listen to #{playlist.name}#{title_suffix}")
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
    let(:show) { create(:show, date: "2024-01-01") }
    let(:path) { "/2024-01-01" }

    it "returns the show title and og tags" do
      show
      expect(service[:title]).to eq("Jan 1, 2024#{title_suffix}")
      expect(service[:og][:title]).to eq("Listen to Phish perform on January 1, 2024")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a show date with a valid track slug" do
    let!(:show) { create(:show, date: "2024-01-01") }
    let!(:track) { create(:track, show:) }
    let(:path) { "/2024-01-01/#{track.slug}" }

    it "returns the track title and og tags" do
      expect(service[:title]).to eq("#{track.title} - Jan 1, 2024#{title_suffix}")
      expect(service[:og][:title]).to eq("Listen to Phish perform #{track.title} on January 1, 2024")
      expect(service[:status]).to eq(:ok)
    end
  end

  context "when the path is a show date with an invalid track slug" do
    let(:show) { create(:show, date: "2024-01-01") }
    let(:path) { "/2024-01-01/invalid-slug" }

    it "returns the show title without track details and status ok" do
      show
      expect(service[:title]).to eq("Jan 1, 2024#{title_suffix}")
      expect(service[:og][:title]).to eq("Listen to Phish perform on January 1, 2024")
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

    it "returns the year title" do
      show
      expect(service[:title]).to eq("2023#{title_suffix}")
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

    it "returns the tag title for shows" do
      expect(service[:title]).to eq("#{tag.name} - Shows#{title_suffix}")
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

    it "returns the song title and og tags" do
      expect(service[:title]).to eq("#{song.name}#{title_suffix}")
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

    it "returns the venue title and og tags" do
      expect(service[:title]).to eq("#{venue.name}#{title_suffix}")
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
