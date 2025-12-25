require "rails_helper"

RSpec.describe Mcp::GetShowService do
  let!(:venue) { create(:venue, city: "New York", state: "NY", country: "USA") }
  let!(:tour) { create(:tour, name: "Summer 1997") }
  let!(:song) { create(:song, title: "Tweezer") }
  let!(:tag) { create(:tag, name: "Jam Chart") }

  let!(:show) do
    create(:show,
      date: "1997-12-31",
      venue: venue,
      tour: tour,
      duration: 3_600_000,
      taper_notes: "Great recording"
    )
  end

  let!(:track) do
    create(:track,
      show: show,
      position: 1,
      title: "Tweezer",
      set: "2",
      duration: 1_200_000,
      songs: [song]
    )
  end

  let!(:show_tag) { create(:show_tag, show: show, tag: tag, notes: "Epic show") }

  describe "#call" do
    subject { described_class.call(date: date) }

    context "with valid date" do
      let(:date) { "1997-12-31" }

      it "returns show data" do
        expect(subject[:date]).to eq("1997-12-31")
        expect(subject[:tour]).to eq("Summer 1997")
        expect(subject[:duration_ms]).to eq(3_600_000)
      end

      it "includes venue information" do
        expect(subject[:venue][:name]).to eq(show.venue_name)
        expect(subject[:venue][:city]).to eq("New York")
        expect(subject[:venue][:state]).to eq("NY")
      end

      it "includes tracks" do
        expect(subject[:tracks]).to be_an(Array)
        expect(subject[:tracks].first[:title]).to eq("Tweezer")
        expect(subject[:tracks].first[:set_name]).to eq("Set 2")
      end

      it "includes track songs" do
        expect(subject[:tracks].first[:songs]).to include(
          hash_including(title: "Tweezer", slug: song.slug)
        )
      end

      it "includes show tags" do
        expect(subject[:tags]).to include(
          hash_including(name: "Jam Chart", notes: "Epic show")
        )
      end

      it "includes navigation" do
        expect(subject[:navigation]).to include(
          :previous_show, :next_show, :previous_show_with_audio, :next_show_with_audio
        )
      end

      it "formats duration" do
        expect(subject[:duration_display]).to eq("1:00:00")
        expect(subject[:tracks].first[:duration_display]).to eq("20:00")
      end
    end

    context "with include_tracks: false" do
      subject { described_class.call(date: "1997-12-31", include_tracks: false) }

      it "excludes tracks" do
        expect(subject[:tracks]).to be_nil
      end
    end

    context "with invalid date" do
      let(:date) { "2099-01-01" }

      it "returns error" do
        expect(subject[:error]).to eq("Show not found for date: 2099-01-01")
      end
    end

    context "with navigation between shows" do
      let!(:earlier_show) { create(:show, date: "1997-12-30", venue: venue, tour: tour) }
      let!(:later_show) { create(:show, date: "1998-01-01", venue: venue, tour: tour) }
      let(:date) { "1997-12-31" }

      it "includes previous and next show dates" do
        expect(subject[:navigation][:previous_show]).to eq("1997-12-30")
        expect(subject[:navigation][:next_show]).to eq("1998-01-01")
      end
    end
  end

  describe "logging" do
    subject do
      described_class.call(
        date: "1997-12-31",
        log_call: true
      )
    end

    it "logs the call" do
      expect { subject }.to change(McpToolCall, :count).by(1)
    end

    it "records tool name" do
      subject
      log = McpToolCall.last
      expect(log.tool_name).to eq("get_show")
    end

    it "records parameters" do
      subject
      log = McpToolCall.last
      expect(log.parameters["date"]).to eq("1997-12-31")
    end
  end
end





