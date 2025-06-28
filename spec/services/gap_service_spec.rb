require "rails_helper"

RSpec.describe GapService do
  subject(:service) { described_class.call(show) }

  let!(:venue) { create(:venue, name: "Madison Square Garden") }
  let!(:show) { create(:show, date: "2023-04-14", venue:) }
  let!(:song1) { create(:song, title: "Blaze On") }
  let!(:song2) { create(:song, title: "My Friend My Friend") }
  let!(:track1) { create(:track, show:, position: 1, set: "1", songs: [song1]) }
  let!(:track2) { create(:track, show:, position: 2, set: "1", songs: [song2]) }

  let(:phishnet_response) do
    {
      "error" => false,
      "error_message" => "",
      "data" => [
        {
          "songid" => 2570,
          "position" => 1,
          "set" => "1",
          "gap" => 4,
          "song" => "Blaze On"
        },
        {
          "songid" => 2571,
          "position" => 2,
          "set" => "1",
          "gap" => 12,
          "song" => "My Friend My Friend"
        }
      ]
    }
  end

    before do
    # Set up API key first
    stub_const("ENV", ENV.to_hash.merge("PNET_API_KEY" => "test_api_key"))

    # Stub the Phish.net API call
    allow(Typhoeus).to receive(:get).and_return(
      double(success?: true, body: phishnet_response.to_json)
    )
  end

  describe "#call" do
    context "when API key is present" do
      it "fetches gap data from Phish.net API" do
        service

        expect(Typhoeus).to have_received(:get).with(
          "https://api.phish.net/v5/setlists/showdate/2023-04-14.json?apikey=test_api_key"
        )
      end

      it "updates previous performance gap data for matching songs" do
        service

        songs_track1 = SongsTrack.find_by(track: track1, song: song1)
        songs_track2 = SongsTrack.find_by(track: track2, song: song2)

        expect(songs_track1.previous_performance_gap).to eq(4)
        expect(songs_track2.previous_performance_gap).to eq(12)

        # Next gaps and slugs should not be set by GapService
        expect(songs_track1.next_performance_gap).to be_nil
        expect(songs_track1.previous_performance_slug).to be_nil
        expect(songs_track1.next_performance_slug).to be_nil
      end
    end

        context "when API key is not present" do
      before do
        stub_const("ENV", ENV.to_hash.merge("PNET_API_KEY" => nil))
      end

      it "returns early without making API calls" do
        service

        expect(Typhoeus).not_to have_received(:get)
      end
    end

    context "when API call fails" do
      before do
        allow(Typhoeus).to receive(:get).and_return(
          double(success?: false, body: "")
        )
      end

      it "handles the failure gracefully" do
        expect { service }.not_to raise_error

        songs_track1 = SongsTrack.find_by(track: track1, song: song1)
        expect(songs_track1.previous_performance_gap).to be_nil
      end
    end

    context "when API returns error" do
      let(:error_response) do
        {
          "error" => true,
          "error_message" => "Invalid date",
          "data" => []
        }
      end

      before do
        allow(Typhoeus).to receive(:get).and_return(
          double(success?: true, body: error_response.to_json)
        )
      end

      it "handles API errors gracefully" do
        expect { service }.not_to raise_error

        songs_track1 = SongsTrack.find_by(track: track1, song: song1)
        expect(songs_track1.previous_performance_gap).to be_nil
      end
    end

    context "when song titles don't match exactly" do
      let(:phishnet_response) do
        {
          "error" => false,
          "error_message" => "",
          "data" => [
            {
              "songid" => 2570,
              "position" => 1,
              "set" => "1",
              "gap" => 4,
              "song" => "Different Song Title"
            }
          ]
        }
      end

      it "skips songs that don't match" do
        service

        songs_track1 = SongsTrack.find_by(track: track1, song: song1)
        expect(songs_track1.previous_performance_gap).to be_nil
      end
    end

        context "with different set mappings" do
      let!(:encore_track) { create(:track, show:, position: 3, set: "3", songs: [song1]) }

      let(:phishnet_response) do
        {
          "error" => false,
          "error_message" => "",
          "data" => [
            {
              "songid" => 2570,
              "position" => 3,
              "set" => "E",  # Encore in Phish.net format
              "gap" => 8,
              "song" => "Blaze On"
            }
          ]
        }
      end

      it "maps Phish.net set notation to local notation" do
        service

        songs_track = SongsTrack.find_by(track: encore_track, song: song1)
        expect(songs_track.previous_performance_gap).to eq(8)
      end
    end
  end

  describe "#find_matching_track" do
    let(:service_instance) { described_class.new(show) }

    it "maps set notation correctly" do
      setlist_item = { "position" => 1, "set" => "1" }
      track = service_instance.send(:find_matching_track, setlist_item)
      expect(track).to eq(track1)
    end

    it "handles encore notation" do
      encore_track = create(:track, show:, position: 4, set: "3")
      setlist_item = { "position" => 4, "set" => "E" }
      track = service_instance.send(:find_matching_track, setlist_item)
      expect(track).to eq(encore_track)
    end
  end
end
