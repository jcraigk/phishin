require "rails_helper"

RSpec.describe GapService, type: :service do
  let(:venue) { create(:venue) }
  let(:tour) { create(:tour) }
  let(:song) { create(:song, title: "Wilson") }

  let(:show1) { create(:show, date: "2023-01-01", venue: venue, tour: tour) }
  let(:show2) { create(:show, date: "2023-01-15", venue: venue, tour: tour) }
  let(:show3) { create(:show, date: "2023-02-01", venue: venue, tour: tour) }

  let(:track1) { create(:track, show: show1, position: 1, set: "1") }
  let(:track2) { create(:track, show: show2, position: 1, set: "1") }
  let(:track3) { create(:track, show: show3, position: 1, set: "1") }

  before do
    # Create songs_tracks associations
    create(:songs_track, song: song, track: track1)
    create(:songs_track, song: song, track: track2)
    create(:songs_track, song: song, track: track3)
  end

  describe "#call" do
    context "when update_previous is false (default)" do
      it "updates previous performance gap for current show" do
        described_class.call(show2)

        song_track2 = SongsTrack.find_by(song: song, track: track2)
        expect(song_track2.previous_performance_gap).to eq(0)
        expect(song_track2.previous_performance_slug).to eq("2023-01-01/#{track1.slug}")
      end

      it "updates next performance gap for current show" do
        described_class.call(show2)

        song_track2 = SongsTrack.find_by(song: song, track: track2)
        expect(song_track2.next_performance_gap).to eq(0)
        expect(song_track2.next_performance_slug).to eq("2023-02-01/#{track3.slug}")
      end

      it "does not update other shows" do
        described_class.call(show2)

        song_track1 = SongsTrack.find_by(song: song, track: track1)
        expect(song_track1.next_performance_gap).to be_nil
        expect(song_track1.next_performance_slug).to be_nil
      end
    end

    context "when update_previous is true" do
      it "updates gaps for current show" do
        described_class.call(show1)
        described_class.call(show2, update_previous: true)

        song_track2 = SongsTrack.find_by(song: song, track: track2)
        expect(song_track2.previous_performance_gap).to eq(0)
        expect(song_track2.previous_performance_slug).to eq("2023-01-01/#{track1.slug}")
      end

      it "updates gaps for previous occurrences" do
        described_class.call(show1)
        described_class.call(show2, update_previous: true)

        song_track1 = SongsTrack.find_by(song: song, track: track1)
        expect(song_track1.next_performance_gap).to eq(0)
        expect(song_track1.next_performance_slug).to eq("2023-01-15/#{track2.slug}")
      end
    end
  end

  describe "gap calculations" do
    context "with shows having different audio statuses" do
      let(:show_with_audio) { create(:show, date: "2023-01-05", venue: venue, tour: tour) }
      let(:show_missing_audio) { create(:show, date: "2023-01-10", venue: venue, tour: tour) }
      let(:track_with_audio) { create(:track, show: show_with_audio, position: 1, set: "1") }
      let(:track_missing_audio) { create(:track, show: show_missing_audio, position: 1, set: "1") }

      before do
        create(:songs_track, song: song, track: track_with_audio)
        create(:songs_track, song: song, track: track_missing_audio)

        show1.update!(audio_status: "complete")
        show2.update!(audio_status: "complete")
        show_with_audio.update!(audio_status: "complete")
        show_missing_audio.update!(audio_status: "missing")
      end

      it "calculates regular gaps including all shows" do
        described_class.call(show2)

        song_track2 = SongsTrack.find_by(song: song, track: track2)
        expect(song_track2.previous_performance_gap).to eq(0)
        expect(song_track2.previous_performance_slug).to eq("2023-01-10/#{track_missing_audio.slug}")
      end

      it "calculates audio gaps excluding missing audio shows" do
        described_class.call(show2)

        song_track2 = SongsTrack.find_by(song: song, track: track2)
        expect(song_track2.previous_performance_gap_with_audio).to eq(0)
        expect(song_track2.previous_performance_slug_with_audio).to eq("2023-01-05/#{track_with_audio.slug}")
      end
    end

    context "with same-show performances" do
      let(:track1_later) { create(:track, show: show1, position: 5, set: "2") }

      before do
        create(:songs_track, song: song, track: track1_later)
      end

      it "handles within-show gaps correctly" do
        described_class.call(show1)

        song_track_later = SongsTrack.find_by(song: song, track: track1_later)
        expect(song_track_later.previous_performance_gap).to eq(0)
        expect(song_track_later.previous_performance_slug).to eq("2023-01-01/#{track1.slug}")
      end
    end

    context "with soundcheck tracks" do
      let(:soundcheck_track) { create(:track, show: show1, position: 2, set: "S") }

      before do
        create(:songs_track, song: song, track: soundcheck_track)
      end

      it "excludes soundcheck tracks from gap calculations" do
        described_class.call(show2)

        song_track2 = SongsTrack.find_by(song: song, track: track2)
        expect(song_track2.previous_performance_slug).to eq("2023-01-01/#{track1.slug}")
      end
    end
  end

  describe "edge cases" do
    context "when no previous performance exists" do
      it "sets previous gaps to nil" do
        described_class.call(show1)

        song_track1 = SongsTrack.find_by(song: song, track: track1)
        expect(song_track1.previous_performance_gap).to be_nil
        expect(song_track1.previous_performance_slug).to be_nil
      end
    end

    context "when no next performance exists" do
      it "sets next gaps to nil" do
        described_class.call(show3)

        song_track3 = SongsTrack.find_by(song: song, track: track3)
        expect(song_track3.next_performance_gap).to be_nil
        expect(song_track3.next_performance_slug).to be_nil
      end
    end

    context "with consecutive shows (no gap)" do
      let(:show_consecutive) { create(:show, date: "2023-01-02", venue: venue, tour: tour) }
      let(:track_consecutive) { create(:track, show: show_consecutive, position: 1, set: "1") }

      before do
        create(:songs_track, song: song, track: track_consecutive)
      end

      it "calculates zero gap correctly" do
        described_class.call(show_consecutive)

        song_track_consecutive = SongsTrack.find_by(song: song, track: track_consecutive)
        expect(song_track_consecutive.previous_performance_gap).to eq(0)
        expect(song_track_consecutive.previous_performance_slug).to eq("2023-01-01/#{track1.slug}")
      end
    end

    context "with shows that create actual gaps" do
      let(:first_performance_show) { create(:show, date: "2023-03-10", venue: venue, tour: tour) }
      let(:gap_show1) { create(:show, date: "2023-03-11", venue: venue, tour: tour) }
      let(:gap_show2) { create(:show, date: "2023-03-12", venue: venue, tour: tour) }
      let(:second_performance_show) { create(:show, date: "2023-03-16", venue: venue, tour: tour) }

      let(:first_track) { create(:track, show: first_performance_show, position: 1, set: "1") }
      let(:second_track) { create(:track, show: second_performance_show, position: 1, set: "1") }

      before do
        create(:songs_track, song: song, track: first_track)
        create(:songs_track, song: song, track: second_track)
        gap_show1.save!
        gap_show2.save!
      end

      it "calculates gaps correctly when shows exist between performances" do
        described_class.call(second_performance_show)

        song_track_second = SongsTrack.find_by(song: song, track: second_track)
        expect(song_track_second.previous_performance_gap).to eq(2)
        expect(song_track_second.previous_performance_slug).to eq("2023-03-10/#{first_track.slug}")
      end
    end
  end

  describe "database transactions" do
    let(:songs_track) { SongsTrack.find_by(song: song, track: track1) }

    before do
      allow(songs_track).to receive(:save!).and_raise(StandardError, "Database error")
      allow(SongsTrack).to receive(:find_by).and_return(songs_track)
    end

    it "rolls back changes if an error occurs" do
      expect {
        described_class.call(show1)
      }.to raise_error(StandardError, "Database error")
    end

    it "does not persist changes when transaction fails" do
      described_class.call(show1) rescue StandardError

      song_track1 = SongsTrack.find_by(song: song, track: track1)
      expect(song_track1.previous_performance_gap).to be_nil
    end
  end
end
