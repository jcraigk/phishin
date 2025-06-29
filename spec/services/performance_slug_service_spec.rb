require "rails_helper"

RSpec.describe PerformanceSlugService do
  subject(:service) { described_class.call(current_show) }

  let!(:venue) { create(:venue, name: "Madison Square Garden") }
  let!(:previous_show) { create(:show, date: "2022-12-30", venue:) }
  let!(:current_show) { create(:show, date: "2023-01-01", venue:) }
  let!(:next_show) { create(:show, date: "2023-01-05", venue:) }
  let!(:song) { create(:song, title: "Tweezer") }

  let!(:tracks) do
    [
      create(:track, show: current_show, position: 1, songs: [song]),
      create(:track, show: current_show, position: 5, songs: [song]),
      create(:track, show: current_show, position: 10, songs: [song]),
      create(:track, show: previous_show, position: 1, songs: [song]),
      create(:track, show: next_show, position: 1, songs: [song])
    ]
  end

  before do
    # Set up some previous performance gaps (as if PerformanceGapService already ran)
    SongsTrack.find_by(track: tracks[0], song: song).update!(previous_performance_gap: 2)
    SongsTrack.find_by(track: tracks[1], song: song).update!(previous_performance_gap: 0)
    SongsTrack.find_by(track: tracks[2], song: song).update!(previous_performance_gap: 0)
    SongsTrack.find_by(track: tracks[3], song: song).update!(previous_performance_gap: 5)
    SongsTrack.find_by(track: tracks[4], song: song).update!(previous_performance_gap: 4)

    service
  end

  describe "#call" do
    it "sets previous performance slugs correctly" do
      first_song_track = SongsTrack.find_by(track: tracks[0], song: song)
      expect(first_song_track.previous_performance_slug).to eq("2022-12-30/#{tracks[3].slug}")

      second_song_track = SongsTrack.find_by(track: tracks[1], song: song)
      expect(second_song_track.previous_performance_slug).to eq("2023-01-01/#{tracks[0].slug}")

      third_song_track = SongsTrack.find_by(track: tracks[2], song: song)
      expect(third_song_track.previous_performance_slug).to eq("2023-01-01/#{tracks[1].slug}")
    end

    it "sets next performance slugs correctly" do
      first_song_track = SongsTrack.find_by(track: tracks[0], song: song)
      expect(first_song_track.next_performance_slug).to eq("2023-01-01/#{tracks[1].slug}")

      second_song_track = SongsTrack.find_by(track: tracks[1], song: song)
      expect(second_song_track.next_performance_slug).to eq("2023-01-01/#{tracks[2].slug}")

      third_song_track = SongsTrack.find_by(track: tracks[2], song: song)
      expect(third_song_track.next_performance_slug).to eq("2023-01-05/#{tracks[4].slug}")
    end

    it "does not modify next performance gaps" do
      first_song_track = SongsTrack.find_by(track: tracks[0], song: song)
      second_song_track = SongsTrack.find_by(track: tracks[1], song: song)
      third_song_track = SongsTrack.find_by(track: tracks[2], song: song)

      # Should not modify existing gap values
      expect(first_song_track.next_performance_gap).to be_nil
      expect(second_song_track.next_performance_gap).to be_nil
      expect(third_song_track.next_performance_gap).to be_nil
    end

    it "skips soundcheck tracks" do
      soundcheck_track = create(:track, show: current_show, position: 20, set: "S", songs: [song])

      # Run the service again to process the new track
      described_class.call(current_show)

      songs_track = SongsTrack.find_by(track: soundcheck_track, song: song)

      expect(songs_track.previous_performance_slug).to be_nil
      expect(songs_track.next_performance_slug).to be_nil
    end

    it "handles songs with no previous performance" do
      new_song = create(:song, title: "New Song")
      new_track = create(:track, show: current_show, position: 15, songs: [new_song])

      described_class.call(current_show)

      songs_track = SongsTrack.find_by(track: new_track, song: new_song)
      expect(songs_track.previous_performance_slug).to be_nil
    end

    it "handles songs with no next performance" do
      # The last track in the last show should have no next performance
      last_song_track = SongsTrack.find_by(track: tracks[4], song: song)

      described_class.call(next_show)

      expect(last_song_track.next_performance_slug).to be_nil
    end
  end

  describe "#find_previous_performance" do
    let(:service_instance) { described_class.new(current_show) }

    it "finds previous performance within the same show first" do
      track = tracks[1] # Second track in current show
      previous_track = service_instance.send(:find_previous_performance, song, track)
      expect(previous_track).to eq(tracks[0])
    end

    it "finds previous performance from earlier show when no earlier track in same show" do
      track = tracks[0] # First track in current show
      previous_track = service_instance.send(:find_previous_performance, song, track)
      expect(previous_track).to eq(tracks[3])
    end
  end

  describe "#find_next_performance" do
    let(:service_instance) { described_class.new(current_show) }

    it "finds next performance within the same show first" do
      track = tracks[0] # First track in current show
      next_track = service_instance.send(:find_next_performance, song, track)
      expect(next_track).to eq(tracks[1])
    end

    it "finds next performance from later show when no later track in same show" do
      track = tracks[2] # Last track in current show
      next_track = service_instance.send(:find_next_performance, song, track)
      expect(next_track).to eq(tracks[4])
    end
  end

  describe "#build_slug" do
    let(:service_instance) { described_class.new(current_show) }

    it "builds correct slug format" do
      track = tracks[0]
      slug = service_instance.send(:build_slug, track)
      expect(slug).to eq("2023-01-01/#{track.slug}")
    end

    it "returns nil for nil track" do
      slug = service_instance.send(:build_slug, nil)
      expect(slug).to be_nil
    end
  end
end
