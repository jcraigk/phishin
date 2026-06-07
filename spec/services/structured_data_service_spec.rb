require "rails_helper"

RSpec.describe StructuredDataService do
  subject(:graphs) { described_class.call(path) }

  def graph_of(type)
    graphs.find { |g| g[:@type] == type }
  end

  context "when the path is root" do
    let(:path) { "/" }

    it "emits a WebSite with a SearchAction and a MusicGroup" do
      website = graph_of("WebSite")
      music_group = graph_of("MusicGroup")

      expect(website).to be_present
      expect(website.dig(:potentialAction, :@type)).to eq("SearchAction")
      expect(website.dig(:potentialAction, :target, :urlTemplate)).to include("search?term=")

      expect(music_group).to be_present
      expect(music_group[:name]).to eq("Phish")
      expect(music_group[:sameAs]).to be_an(Array).and be_present
    end
  end

  context "when the path is a show date" do
    let!(:venue) { create(:venue, city: "New York", state: "NY", country: "USA", latitude: 40.7, longitude: -74.0) }
    let!(:show) { create(:show, :with_tracks, date: "2024-01-01", venue:) }
    let(:path) { "/2024-01-01" }

    it "emits a MusicEvent with performer, date, and located venue geo" do
      event = graph_of("MusicEvent")

      expect(event).to be_present
      expect(event[:startDate]).to eq("2024-01-01")
      expect(event.dig(:performer, :name)).to eq("Phish")
      expect(event.dig(:location, :@type)).to eq("MusicVenue")
      expect(event.dig(:location, :address, :addressLocality)).to eq("New York")
      expect(event.dig(:location, :geo, :latitude)).to eq(40.7)
    end
  end

  context "when the path is a show date with no matching show" do
    let(:path) { "/2099-01-01" }

    it "returns no graphs" do
      expect(graphs).to eq([])
    end
  end

  context "when the path is a track" do
    let!(:show) { create(:show, date: "2024-01-01") }
    let!(:track) { create(:track, show:, duration: 150_000) }
    let(:path) { "/2024-01-01/#{track.slug}" }

    it "emits a MusicRecording with artist and ISO 8601 duration" do
      recording = graph_of("MusicRecording")

      expect(recording).to be_present
      expect(recording[:name]).to eq(track.title)
      expect(recording.dig(:byArtist, :name)).to eq("Phish")
      expect(recording[:duration]).to eq("PT2M30S")
    end
  end

  context "when the path is a song" do
    let!(:song) { create(:song) }
    let(:path) { "/songs/#{song.slug}" }

    it "emits a MusicComposition" do
      composition = graph_of("MusicComposition")

      expect(composition).to be_present
      expect(composition[:name]).to eq(song.title)
    end
  end

  context "when the path is a venue" do
    let!(:venue) { create(:venue, latitude: 40.7, longitude: -74.0) }
    let(:path) { "/venues/#{venue.slug}" }

    it "emits a MusicVenue with geo coordinates" do
      place = graph_of("MusicVenue")

      expect(place).to be_present
      expect(place[:name]).to eq(venue.name)
      expect(place.dig(:geo, :latitude)).to eq(40.7)
    end
  end

  context "when the path is a playlist" do
    let!(:playlist) { create(:playlist) }
    let(:path) { "/play/#{playlist.slug}" }

    it "emits a MusicPlaylist" do
      list = graph_of("MusicPlaylist")

      expect(list).to be_present
      expect(list[:name]).to eq(playlist.name)
    end
  end

  context "when the path is a static page" do
    let(:path) { "/faq" }

    it "returns no graphs" do
      expect(graphs).to eq([])
    end
  end
end
