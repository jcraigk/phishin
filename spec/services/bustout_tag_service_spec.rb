require "rails_helper"

RSpec.describe BustoutTagService do
  subject(:service) { described_class.call(show) }

  let!(:venue) { create(:venue, name: "Madison Square Garden") }
  let!(:show) { create(:show, date: "2023-01-01", venue:) }
  let!(:song) { create(:song, title: "Tweezer") }
  let!(:bustout_tag) { create(:tag, name: "Bustout") }
  let!(:track) { create(:track, show:, position: 1, songs: [ song ]) }

  before do
    # Set up a songs_track with a large gap to trigger bustout tag
    songs_track = SongsTrack.find_by(track_id: track.id, song_id: song.id)
    songs_track.update!(previous_performance_gap: 150)
  end

  describe "#call" do
    context "when a song has a large performance gap" do
      it "applies the bustout tag" do
        expect { service }.to change { track.track_tags.count }.by(1)

        track_tag = track.track_tags.find_by(tag: bustout_tag)
        expect(track_tag).to be_present
        expect(track_tag.notes).to eq("First performance of Tweezer in 150 shows")
      end
    end

    context "when a song has a small performance gap" do
      before do
        songs_track = SongsTrack.find_by(track_id: track.id, song_id: song.id)
        songs_track.update!(previous_performance_gap: 50)
      end

      it "does not apply the bustout tag" do
        expect { service }.not_to change { track.track_tags.count }
      end
    end

    context "when the track already has a bustout tag" do
      before do
        track.track_tags.create!(tag: bustout_tag, notes: "Existing bustout tag")
      end

      it "does not create a duplicate bustout tag" do
        expect { service }.not_to change { track.track_tags.count }
      end
    end

    context "when the track is in a soundcheck set" do
      let!(:soundcheck_track) { create(:track, show:, position: 2, set: "S", songs: [ song ]) }

      before do
        songs_track = SongsTrack.find_by(track_id: soundcheck_track.id, song_id: song.id)
        songs_track.update!(previous_performance_gap: 150)
      end

      it "does not apply bustout tag to soundcheck tracks" do
        described_class.call(show)

        expect(soundcheck_track.track_tags.where(tag: bustout_tag)).to be_empty
      end
    end

    context "when no performance gap is present" do
      before do
        songs_track = SongsTrack.find_by(track_id: track.id, song_id: song.id)
        songs_track.update!(previous_performance_gap: nil)
      end

      it "does not apply the bustout tag" do
        expect { service }.not_to change { track.track_tags.count }
      end
    end
  end
end
