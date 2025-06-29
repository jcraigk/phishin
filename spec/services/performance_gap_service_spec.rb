require "rails_helper"

RSpec.describe PerformanceGapService do
  subject(:service) { described_class.call(show) }

  let!(:venue) { create(:venue, name: "Madison Square Garden") }
  let!(:earlier_show) { create(:show, date: "2022-12-30", venue:) }
  let!(:show) { create(:show, date: "2023-04-14", venue:) }
  let!(:song1) { create(:song, title: "Blaze On") }
  let!(:song2) { create(:song, title: "My Friend My Friend") }
  let!(:song3) { create(:song, title: "Tweezer") }


  # Current show tracks (note: positions may not match Phish.net due to Banter, etc.)
  let!(:track2) { create(:track, show:, position: 2, set: "1", title: "Blaze On", songs: [ song1 ]) }
  let!(:track3) { create(:track, show:, position: 3, set: "1", title: "My Friend My Friend", songs: [ song2 ]) }
  let!(:track4) { create(:track, show:, position: 4, set: "1", title: "Tweezer > Harry Hood", songs: [ song3 ]) }
  let!(:track5) { create(:track, show:, position: 5, set: "1", title: "Tweezer", songs: [ song3 ]) } # Duplicate song

  # Earlier show track
  let!(:earlier_track) { create(:track, show: earlier_show, position: 1, set: "1", songs: [ song3 ]) }

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
          "songid" => 123,
          "position" => 2,
          "set" => "1",
          "gap" => 12,
          "song" => "My Friend My Friend"
        },
        {
          "songid" => 456,
          "position" => 3,
          "set" => "1",
          "gap" => 8,
          "song" => "Tweezer"
        },
        {
          "songid" => 456,
          "position" => 4,
          "set" => "1",
          "gap" => 25, # This should be ignored since it's a duplicate
          "song" => "Tweezer"
        },
        {
          "songid" => 2570,
          "position" => 1,
          "set" => "E",  # Encore
          "gap" => 8,
          "song" => "Blaze On"
        }
      ]
    }
  end

  let(:successful_response) { instance_double(Typhoeus::Response, success?: true, body: phishnet_response.to_json) }
  let(:failed_response) { instance_double(Typhoeus::Response, success?: false, body: "") }

  before do
    # Set up API key first
    stub_const("ENV", ENV.to_hash.merge("PNET_API_KEY" => "test_api_key"))

    # Stub the Phish.net API call
    allow(Typhoeus).to receive(:get).and_return(successful_response)
  end

  describe "#call" do
    context "when API key is present" do
      it "updates previous performance gap data for matching songs by title" do
        service
        expect_correct_gap_updates
      end

      it "updates next_performance_gap on earlier performances" do
        service

        # The earlier show's Tweezer should have its next_performance_gap updated
        earlier_songs_track = SongsTrack.find_by(track: earlier_track, song: song3)
        expect(earlier_songs_track.next_performance_gap).to eq(8)
      end

      it "does not update next_performance_gap for duplicate songs" do
        earlier_show2 = create(:show, date: "2022-12-25", venue:)
        earlier_track2 = create(:track, show: earlier_show2, position: 1, set: "1", songs: [ song3 ])

        service

        # The second earlier show should not be updated since the duplicate gets gap 0
        earlier_songs_track2 = SongsTrack.find_by(track: earlier_track2, song: song3)
        expect(earlier_songs_track2.next_performance_gap).to be_nil
      end

      it "fetches gap data from Phish.net API" do
        service

        expect(Typhoeus).to have_received(:get).with(
          "https://api.phish.net/v5/setlists/showdate/2023-04-14.json?apikey=test_api_key"
        )
      end

      it "excludes soundcheck tracks when finding previous performances" do
        soundcheck_show = create(:show, date: "2022-12-28", venue:)
        soundcheck_track = create(:track, show: soundcheck_show, position: 1, set: "S", songs: [ song3 ])

        service
        expect_soundcheck_exclusion(soundcheck_track)
      end

      it "handles case-insensitive song title matching" do
        caps_response = instance_double(Typhoeus::Response, success?: true, body: build_caps_response.to_json)
        allow(Typhoeus).to receive(:get).and_return(caps_response)
        service
        expect(SongsTrack.find_by(track: track2, song: song1).previous_performance_gap).to eq(5)
      end
    end

    context "when song titles don't match exactly" do
      let(:phishnet_response) do
        {
          "error" => false,
          "error_message" => "",
          "data" => [
            {
              "songid" => 999,
              "position" => 1,
              "set" => "1",
              "gap" => 5,
              "song" => "Non-existent Song"
            }
          ]
        }
      end

      it "skips songs that don't match" do
        service

        # No songs_tracks should be updated
        expect(SongsTrack.where.not(previous_performance_gap: nil)).to be_empty
      end
    end

    context "when API call fails" do
      before do
        allow(Typhoeus).to receive(:get).and_return(failed_response)
      end

      it "handles the failure gracefully" do
        expect { service }.not_to raise_error

        # No songs_tracks should be updated
        expect(SongsTrack.where.not(previous_performance_gap: nil)).to be_empty
      end
    end

    context "when API returns error" do
      let(:phishnet_response) do
        {
          "error" => true,
          "error_message" => "Date not found",
          "data" => []
        }
      end

      it "handles API errors gracefully" do
        expect { service }.not_to raise_error

        # No songs_tracks should be updated
        expect(SongsTrack.where.not(previous_performance_gap: nil)).to be_empty
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

    context "with encore sets" do
      let!(:encore_track) { create(:track, show:, position: 6, set: "E", songs: [ song1 ]) }

      it "handles encore set notation" do
        service

        songs_track = SongsTrack.find_by(track: encore_track, song: song1)
        expect(songs_track.previous_performance_gap).to eq(0) # Should be 0 since Blaze On already appeared earlier
      end
    end
  end

  describe "#find_matching_songs_track" do
    let(:service_instance) { described_class.new(show) }
    let(:songs_tracks) do
      [
        SongsTrack.find_by(track: track2, song: song1),
        SongsTrack.find_by(track: track3, song: song2),
        SongsTrack.find_by(track: track4, song: song3),
        SongsTrack.find_by(track: track5, song: song3)
      ]
    end
    let(:matched_songs_track_ids) { Set.new }

    it "matches songs by title case-insensitively" do
      setlist_item = { "song" => "BLAZE ON" }
      songs_track = service_instance.send(:find_matching_songs_track, setlist_item, songs_tracks, matched_songs_track_ids)
      expect(songs_track.song).to eq(song1)
    end

    it "matches the first occurrence of duplicate songs" do
      setlist_item = { "song" => "Tweezer" }
      songs_track = service_instance.send(:find_matching_songs_track, setlist_item, songs_tracks, matched_songs_track_ids)
      expect(songs_track.track).to eq(track4) # First Tweezer track
    end

    it "returns nil for non-matching songs" do
      setlist_item = { "song" => "Non-existent Song" }
      songs_track = service_instance.send(:find_matching_songs_track, setlist_item, songs_tracks, matched_songs_track_ids)
      expect(songs_track).to be_nil
    end
  end

  describe "#find_most_recent_previous_performance" do
    let(:service_instance) { described_class.new(show) }

    it "finds the most recent previous performance" do
      show2 = create(:show, date: "2022-12-28", venue:)
      create(:track, show: create(:show, date: "2022-12-25", venue:), position: 1, set: "1", songs: [ song1 ])
      track_recent = create(:track, show: show2, position: 2, set: "1", songs: [ song1 ])
      expect(service_instance.send(:find_most_recent_previous_performance, song1).track).to eq(track_recent)
    end

    it "excludes soundcheck tracks" do
      regular_track = create(:track, show: create(:show, date: "2022-12-25", venue:), position: 1, set: "1", songs: [ song1 ])
      create(:track, show: create(:show, date: "2022-12-27", venue:), position: 1, set: "S", songs: [ song1 ])
      expect(service_instance.send(:find_most_recent_previous_performance, song1).track).to eq(regular_track)
    end
  end

  private

  def expect_correct_gap_updates
    songs_track1 = SongsTrack.find_by(track: track2, song: song1)
    songs_track2 = SongsTrack.find_by(track: track3, song: song2)
    songs_track3 = SongsTrack.find_by(track: track4, song: song3)
    songs_track4 = SongsTrack.find_by(track: track5, song: song3)

    expect(songs_track1.previous_performance_gap).to eq(4)
    expect(songs_track2.previous_performance_gap).to eq(12)
    expect(songs_track3.previous_performance_gap).to eq(8)
    expect(songs_track4.previous_performance_gap).to eq(0) # Duplicate gets 0
  end

  def expect_soundcheck_exclusion(soundcheck_track)
    # The soundcheck track should not be updated
    soundcheck_songs_track = SongsTrack.find_by(track: soundcheck_track, song: song3)
    expect(soundcheck_songs_track.next_performance_gap).to be_nil

    # The regular earlier track should still be updated
    earlier_songs_track = SongsTrack.find_by(track: earlier_track, song: song3)
    expect(earlier_songs_track.next_performance_gap).to eq(8)
  end

  def build_caps_response
    {
      "error" => false,
      "error_message" => "",
      "data" => [
        {
          "songid" => 2570,
          "position" => 1,
          "set" => "1",
          "gap" => 5,
          "song" => "Blaze On"
        }
      ]
    }
  end
end
