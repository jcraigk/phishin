require "rails_helper"

RSpec.describe ChronologicalTrackNavigator do
  let!(:show1) { create(:show, date: "2020-01-01") }
  let!(:show2) { create(:show, date: "2020-01-02") }
  let!(:show3) { create(:show, date: "2020-01-03") }

  let!(:track1_1) { create(:track, show: show1, position: 1, set: "1", audio_status: "complete") }
  let!(:track1_2) { create(:track, show: show1, position: 2, set: "1", audio_status: "complete") }
  let!(:track1_3) { create(:track, show: show1, position: 3, set: "2", audio_status: "complete") }

  let!(:track2_1) { create(:track, show: show2, position: 1, set: "1", audio_status: "complete") }

  let!(:track3_1) { create(:track, show: show3, position: 1, set: "1", audio_status: "complete") }

  describe ".call" do
    context "with direction :next" do
      it "returns the next track in the same show" do
        result = described_class.call(track1_1, direction: :next)
        expect(result).to eq(track1_2)
      end

      it "returns the first track of the next show when at end of current show" do
        result = described_class.call(track1_3, direction: :next)
        expect(result).to eq(track2_1)
      end

      it "wraps around to first track when at the end of the library" do
        result = described_class.call(track3_1, direction: :next)
        expect(result).to eq(track1_1)
      end
    end

    context "with direction :prev" do
      it "returns the previous track in the same show" do
        result = described_class.call(track1_2, direction: :prev)
        expect(result).to eq(track1_1)
      end

      it "returns the last track of the previous show when at start of current show" do
        result = described_class.call(track2_1, direction: :prev)
        expect(result).to eq(track1_3)
      end

      it "wraps around to last track when at the start of the library" do
        result = described_class.call(track1_1, direction: :prev)
        expect(result).to eq(track3_1)
      end
    end
  end

  describe ".first_track" do
    it "returns the chronologically first track with audio" do
      expect(described_class.first_track).to eq(track1_1)
    end
  end

  describe ".last_track" do
    it "returns the chronologically last track with audio" do
      expect(described_class.last_track).to eq(track3_1)
    end
  end

  describe ".playable_tracks_for_show" do
    it "returns only playable tracks ordered by position" do
      tracks = described_class.playable_tracks_for_show(show1)
      expect(tracks).to eq([ track1_1, track1_2, track1_3 ])
    end

    it "excludes soundcheck (S) and pre-show (P) tracks" do
      soundcheck = create(:track, show: show1, position: 0, set: "S", audio_status: "complete")
      preshow = create(:track, show: show1, position: 4, set: "P", audio_status: "complete")

      tracks = described_class.playable_tracks_for_show(show1)
      expect(tracks).not_to include(soundcheck, preshow)
    end

    it "excludes tracks without audio" do
      no_audio = create(:track, show: show1, position: 5, set: "1", audio_status: "missing")

      tracks = described_class.playable_tracks_for_show(show1)
      expect(tracks).not_to include(no_audio)
    end
  end

  describe ".adjacent_show" do
    context "with direction :next" do
      it "returns the next show with audio" do
        result = described_class.adjacent_show(show1, direction: :next)
        expect(result).to eq(show2)
      end

      it "returns nil when at the last show" do
        result = described_class.adjacent_show(show3, direction: :next)
        expect(result).to be_nil
      end
    end

    context "with direction :prev" do
      it "returns the previous show with audio" do
        result = described_class.adjacent_show(show2, direction: :prev)
        expect(result).to eq(show1)
      end

      it "returns nil when at the first show" do
        result = described_class.adjacent_show(show1, direction: :prev)
        expect(result).to be_nil
      end
    end
  end
end
