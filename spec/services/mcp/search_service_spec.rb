require "rails_helper"

RSpec.describe Mcp::SearchService do
  let!(:venue) { create(:venue, name: "Madison Square Garden", city: "New York", state: "NY") }
  let!(:tour) { create(:tour, name: "Summer 1997") }
  let!(:song) { create(:song, title: "Tweezer", original: true) }
  let!(:tag) { create(:tag, name: "Jam Chart", description: "Notable jam") }
  let!(:show) { create(:show, date: "1997-12-31", venue: venue, tour: tour) }

  describe "#call" do
    context "searching all categories" do
      subject { described_class.call(query: "madison") }

      it "returns results from multiple categories" do
        expect(subject).to include(:shows, :songs, :venues, :tags, :playlists)
      end

      it "includes query in response" do
        expect(subject[:query]).to eq("madison")
      end

      it "includes total results count" do
        expect(subject[:total_results]).to be_a(Integer)
      end
    end

    context "searching shows" do
      subject { described_class.call(query: "1997-12-31") }

      it "finds shows by date" do
        expect(subject[:shows]).to be_an(Array)
        expect(subject[:shows].first[:date]).to eq("1997-12-31")
      end

      it "returns show details" do
        show_result = subject[:shows].first
        expect(show_result[:type]).to eq("show")
        expect(show_result[:venue_name]).to be_present
        expect(show_result[:audio_status]).to be_present
      end
    end

    context "searching songs" do
      subject { described_class.call(query: "tweezer") }

      it "finds songs by title" do
        expect(subject[:songs]).to be_an(Array)
        expect(subject[:songs].first[:title]).to eq("Tweezer")
      end

      it "returns song details" do
        song_result = subject[:songs].first
        expect(song_result[:type]).to eq("song")
        expect(song_result[:slug]).to eq(song.slug)
        expect(song_result[:original]).to be true
      end
    end

    context "searching venues" do
      subject { described_class.call(query: "madison") }

      it "finds venues by name" do
        expect(subject[:venues]).to be_an(Array)
        expect(subject[:venues].first[:name]).to eq("Madison Square Garden")
      end

      it "returns venue details" do
        venue_result = subject[:venues].first
        expect(venue_result[:type]).to eq("venue")
        expect(venue_result[:location]).to be_present
      end
    end

    context "searching venues by city" do
      subject { described_class.call(query: "new york") }

      it "finds venues by city" do
        expect(subject[:venues].first[:name]).to eq("Madison Square Garden")
      end
    end

    context "searching tags" do
      subject { described_class.call(query: "jam") }

      it "finds tags by name" do
        expect(subject[:tags]).to be_an(Array)
        expect(subject[:tags].first[:name]).to eq("Jam Chart")
      end

      it "finds tags by description" do
        result = described_class.call(query: "notable")
        expect(result[:tags].first[:name]).to eq("Jam Chart")
      end
    end

    context "with limit" do
      before do
        5.times { |i| create(:song, title: "Test Song #{i}") }
      end

      subject { described_class.call(query: "test song", limit: 3) }

      it "respects limit" do
        expect(subject[:songs].length).to eq(3)
      end
    end

    context "with invalid query" do
      subject { described_class.call(query: "a") }

      it "returns error for short query" do
        expect(subject[:error]).to include("at least")
      end
    end

    context "with no results" do
      subject { described_class.call(query: "xyznonexistent") }

      it "returns empty arrays" do
        expect(subject[:songs]).to eq([])
        expect(subject[:venues]).to eq([])
        expect(subject[:total_results]).to eq(0)
      end
    end
  end

  describe "logging" do
    subject do
      described_class.call(
        query: "tweezer",
        log_call: true
      )
    end

    it "logs the call" do
      expect { subject }.to change(McpToolCall, :count).by(1)
    end

    it "records tool name" do
      subject
      log = McpToolCall.last
      expect(log.tool_name).to eq("search")
    end

    it "records parameters" do
      subject
      log = McpToolCall.last
      expect(log.parameters["query"]).to eq("tweezer")
    end

    it "records result count" do
      subject
      log = McpToolCall.last
      expect(log.result_count).to be >= 1
    end
  end
end
