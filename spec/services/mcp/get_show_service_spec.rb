require "rails_helper"

RSpec.describe Mcp::GetShowService do
  let(:venue) { create(:venue, city: "New York", state: "NY", country: "USA") }
  let(:tour) { create(:tour, name: "Summer 1997") }
  let(:song) { create(:song, title: "Tweezer") }
  let(:tag) { create(:tag, name: "Jam Chart") }

  let(:show) do
    create(:show, date: "1997-12-31", venue:, tour:, duration: 3_600_000, taper_notes: "Great recording")
  end

  let(:track) do
    create(:track, show:, position: 1, title: "Tweezer", set: "2", duration: 1_200_000, songs: [ song ])
  end

  let(:show_tag) { create(:show_tag, show:, tag:, notes: "Epic show") }

  describe "#call" do
    subject(:result) { described_class.call(date:) }

    before do
      track
      show_tag
    end

    context "with valid date" do
      let(:date) { "1997-12-31" }

      it "returns show data", :aggregate_failures do
        expect(result).to include(date: "1997-12-31", tour: "Summer 1997", duration_ms: 3_600_000)
        expect(result[:venue]).to include(name: show.venue_name, city: "New York")
        expect(result[:tracks].first).to include(title: "Tweezer", set_name: "Set 2")
      end

      it "includes tags and navigation", :aggregate_failures do
        expect(result[:tags]).to include(hash_including(name: "Jam Chart"))
        expect(result[:navigation]).to include(:previous_show, :next_show)
      end
    end

    context "with invalid date" do
      let(:date) { "2099-01-01" }

      it "returns error" do
        expect(result[:error]).to eq("Show not found for date: 2099-01-01")
      end
    end

    context "with navigation between shows" do
      let(:date) { "1997-12-31" }

      before do
        create(:show, date: "1997-12-30", venue:, tour:)
        create(:show, date: "1998-01-01", venue:, tour:)
      end

      it "includes previous and next show dates" do
        expect(result[:navigation][:previous_show]).to eq("1997-12-30")
        expect(result[:navigation][:next_show]).to eq("1998-01-01")
      end
    end
  end

  describe "logging" do
    subject(:result) { described_class.call(date: "1997-12-31", log_call: true) }

    before do
      track
      show_tag
    end

    it "logs the call with tool name and parameters" do
      expect { result }.to change(McpToolCall, :count).by(1)
      log = McpToolCall.last
      expect(log.tool_name).to eq("get_show")
      expect(log.parameters["date"]).to eq("1997-12-31")
    end
  end
end
