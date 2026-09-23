require "rails_helper"

RSpec.describe CrawlableContentService do
  subject(:content) { described_class.call(path) }

  context "when the path is a published show" do
    let!(:show) { create(:show, date: "2024-01-01") }
    let(:path) { "/2024-01-01" }

    it "returns the show partial with the show" do
      expect(content).to eq(partial: "crawlable/show", locals: { show: })
    end
  end

  context "when the show is unpublished" do
    let(:path) { "/2024-01-01" }

    before { create(:show, date: "2024-01-01", published: false) }

    it "returns nil" do
      expect(content).to be_nil
    end
  end

  context "when the date is invalid" do
    let(:path) { "/2024-13-45" }

    it "returns nil" do
      expect(content).to be_nil
    end
  end

  context "when the path is a track page" do
    let!(:show) { create(:show, date: "2024-01-01") }
    let!(:track) { create(:track, show:, title: "Tweezer", slug: "tweezer") }
    let(:path) { "/2024-01-01/tweezer" }

    it "returns the track partial with the show and track" do
      expect(content).to eq(partial: "crawlable/track", locals: { show:, track: })
    end
  end

  context "when the track slug does not exist" do
    let(:path) { "/2024-01-01/nope" }

    before { create(:show, date: "2024-01-01") }

    it "returns nil" do
      expect(content).to be_nil
    end
  end

  context "when the path is a song page" do
    let!(:song) { create(:song, title: "Tweezer") }
    let(:path) { "/songs/#{song.slug}" }

    it "returns the song partial with the song" do
      expect(content).to include(partial: "crawlable/song", locals: hash_including(song:))
    end
  end

  context "when the path is a venue page" do
    let!(:venue) { create(:venue) }
    let(:path) { "/venues/#{venue.slug}" }

    it "returns the venue partial with the venue" do
      expect(content).to include(partial: "crawlable/venue", locals: hash_including(venue:))
    end
  end

  context "when the path is a year with shows" do
    let(:path) { "/2024" }

    before { create(:show, date: "2024-01-01") }

    it "returns the year partial" do
      expect(content).to include(partial: "crawlable/year", locals: hash_including(year: 2024))
    end
  end

  context "when the path is a year without shows" do
    let(:path) { "/1950" }

    it "returns nil" do
      expect(content).to be_nil
    end
  end

  context "when the path is an unrelated page" do
    let(:path) { "/top-shows" }

    it "returns nil" do
      expect(content).to be_nil
    end
  end
end
