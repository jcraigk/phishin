require "rails_helper"

RSpec.describe GapService do
  subject(:service) { described_class.new(show, update_previous:) }

  let(:update_previous) { false }
  let!(:venue) { create(:venue) }
  let!(:tour) { create(:tour) }
  let!(:song1) { create(:song, title: "Tweezer") }
  let!(:song2) { create(:song, title: "Fluffhead") }
  let!(:song3) { create(:song, title: "Intro") }
  let!(:show) { create(:show, date: "2023-07-01", venue:, tour:, performance_gap_value: 1) }

  describe "#call" do
    context "with basic track setup" do
      let!(:track1) { create(:track, show:, position: 1, set: "1", songs: [ song1 ]) }

      it "processes the show without errors" do
        expect { service.call }.not_to raise_error
      end

      it "updates gap information for songs_tracks" do
        service.call

        songs_track = SongsTrack.find_by(track: track1, song: song1)
        expect(songs_track).to be_present
        expect(songs_track.previous_performance_gap).to be_nil
      end

      it "sets next performance gap to nil" do
        service.call

        songs_track = SongsTrack.find_by(track: track1, song: song1)
        expect(songs_track.next_performance_gap).to be_nil
      end

      it "sets audio gaps to nil" do
        service.call

        songs_track = SongsTrack.find_by(track: track1, song: song1)
        expect(songs_track.previous_performance_gap_with_audio).to be_nil
        expect(songs_track.next_performance_gap_with_audio).to be_nil
      end
    end

    context "with excluded song titles" do
      let!(:intro_track) { create(:track, show:, position: 1, set: "1", songs: [ song3 ]) }
      let!(:regular_track) { create(:track, show:, position: 2, set: "1", songs: [ song1 ]) }

      it "skips tracks with excluded song titles" do
        service.call

        intro_songs_track = SongsTrack.find_by(track: intro_track, song: song3)
        expect(intro_songs_track.previous_performance_gap).to be_nil
        expect(intro_songs_track.next_performance_gap).to be_nil
      end

      it "processes regular tracks normally" do
        service.call

        regular_songs_track = SongsTrack.find_by(track: regular_track, song: song1)
        expect(regular_songs_track).to be_present
      end
    end

    context "with soundcheck tracks" do
      let!(:soundcheck_track) { create(:track, show:, position: 1, set: "S", songs: [ song1 ]) }
      let!(:regular_track) { create(:track, show:, position: 2, set: "1", songs: [ song2 ]) }

      it "skips soundcheck tracks" do
        service.call

        soundcheck_songs_track = SongsTrack.find_by(track: soundcheck_track, song: song1)
        expect(soundcheck_songs_track.previous_performance_gap).to be_nil
        expect(soundcheck_songs_track.next_performance_gap).to be_nil
      end

      it "processes regular tracks normally" do
        service.call

        regular_songs_track = SongsTrack.find_by(track: regular_track, song: song2)
        expect(regular_songs_track).to be_present
      end
    end

    context "with excluded tracks" do
      let!(:excluded_track) { create(:track, show:, position: 1, set: "1", songs: [ song1 ], exclude_from_performance_gaps: true) }
      let!(:regular_track) { create(:track, show:, position: 2, set: "1", songs: [ song2 ]) }

      it "skips tracks marked for exclusion" do
        service.call

        excluded_songs_track = SongsTrack.find_by(track: excluded_track, song: song1)
        expect(excluded_songs_track.previous_performance_gap).to be_nil
        expect(excluded_songs_track.next_performance_gap).to be_nil
      end

      it "processes regular tracks normally" do
        service.call

        regular_songs_track = SongsTrack.find_by(track: regular_track, song: song2)
        expect(regular_songs_track).to be_present
      end
    end

    context "with multiple shows and performance gaps" do
      let!(:earlier_show) { create(:show, date: "2023-06-01", venue:, tour:, performance_gap_value: 1) }
      let!(:later_show) { create(:show, date: "2023-08-01", venue:, tour:, performance_gap_value: 1) }
      let!(:earlier_track) { create(:track, show: earlier_show, position: 1, set: "1", songs: [ song1 ]) }
      let!(:current_track) { create(:track, show:, position: 4, set: "1", songs: [ song1 ]) }
      let!(:later_track) { create(:track, show: later_show, position: 1, set: "1", songs: [ song1 ]) }

      it "calculates gaps correctly" do
        service.call

        songs_track = SongsTrack.find_by(track: current_track, song: song1)
        expect(songs_track.previous_performance_gap).to eq(1)
        expect(songs_track.next_performance_gap).to eq(1)
      end

      it "sets performance slugs correctly" do
        service.call

        songs_track = SongsTrack.find_by(track: current_track, song: song1)
        expect(songs_track.previous_performance_slug).to eq("#{earlier_show.date}/#{earlier_track.slug}")
        expect(songs_track.next_performance_slug).to eq("#{later_show.date}/#{later_track.slug}")
      end
    end

    context "with shows having different performance_gap_values" do
      let!(:current_track) { create(:track, show:, position: 4, set: "1", songs: [ song1 ]) }

      before do
        show1 = create(:show, date: "2023-06-01", venue:, tour:, performance_gap_value: 1)
        show2 = create(:show, date: "2023-06-15", venue:, tour:, performance_gap_value: 2)
        show3 = create(:show, date: "2023-08-01", venue:, tour:, performance_gap_value: 1)
        create(:track, show: show1, position: 1, set: "1", songs: [ song1 ])
        create(:track, show: show3, position: 1, set: "1", songs: [ song1 ])
      end

      it "uses performance_gap_value in calculations" do
        service.call

        songs_track = SongsTrack.find_by(track: current_track, song: song1)
        expect(songs_track.previous_performance_gap).to eq(3)
        expect(songs_track.next_performance_gap).to eq(1)
      end
    end

    context "with audio status considerations" do
      let!(:current_track) { create(:track, show:, position: 4, set: "1", songs: [ song1 ]) }

      before do
        show1 = create(:show, date: "2023-06-01", venue:, tour:, audio_status: "missing", performance_gap_value: 1)
        show2 = create(:show, date: "2023-05-01", venue:, tour:, audio_status: "complete", performance_gap_value: 1)
        show3 = create(:show, date: "2023-08-01", venue:, tour:, audio_status: "missing", performance_gap_value: 1)
        show4 = create(:show, date: "2023-09-01", venue:, tour:, audio_status: "complete", performance_gap_value: 1)
        create(:track, show: show1, position: 1, set: "1", songs: [ song1 ])
        create(:track, show: show2, position: 1, set: "1", songs: [ song1 ])
        create(:track, show: show3, position: 1, set: "1", songs: [ song1 ])
        create(:track, show: show4, position: 1, set: "1", songs: [ song1 ])
      end

      it "calculates regular gaps including all shows" do
        service.call

        songs_track = SongsTrack.find_by(track: current_track, song: song1)
        expect(songs_track.previous_performance_gap).to eq(1)
        expect(songs_track.next_performance_gap).to eq(1)
      end

      it "calculates audio gaps excluding missing audio shows" do
        service.call

        songs_track = SongsTrack.find_by(track: current_track, song: song1)
        expect(songs_track.previous_performance_gap_with_audio).to eq(1)
        expect(songs_track.next_performance_gap_with_audio).to eq(1)
      end
    end

    context "with pre-show and main show tracks" do
      let!(:preshow_track) { create(:track, show:, position: 1, set: "P", songs: [ song1 ]) }
      let!(:main_track) { create(:track, show:, position: 2, set: "1", songs: [ song1 ]) }

      it "treats pre-show and main show as different performance units" do
        service.call

        preshow_songs_track = SongsTrack.find_by(track: preshow_track, song: song1)
        main_songs_track = SongsTrack.find_by(track: main_track, song: song1)

        expect(preshow_songs_track.next_performance_gap).to eq(1)
        expect(main_songs_track.previous_performance_gap).to eq(1)
      end

      it "sets correct performance slugs for different units" do
        service.call

        preshow_songs_track = SongsTrack.find_by(track: preshow_track, song: song1)
        main_songs_track = SongsTrack.find_by(track: main_track, song: song1)

        expect(preshow_songs_track.next_performance_slug).to eq("#{show.date}/#{main_track.slug}")
        expect(main_songs_track.previous_performance_slug).to eq("#{show.date}/#{preshow_track.slug}")
      end
    end

    context "with multiple tracks in same set" do
      let!(:track1) { create(:track, show:, position: 1, set: "1", songs: [ song1 ]) }
      let!(:track2) { create(:track, show:, position: 2, set: "1", songs: [ song1 ]) }
      let!(:track3) { create(:track, show:, position: 3, set: "1", songs: [ song1 ]) }

      it "finds within-show performances correctly for first track" do
        service.call

        songs_track1 = SongsTrack.find_by(track: track1, song: song1)
        expect(songs_track1.next_performance_gap).to eq(0)
        expect(songs_track1.next_performance_slug).to eq("#{show.date}/#{track2.slug}")
      end

      it "finds within-show performances correctly for middle track" do
        service.call

        songs_track2 = SongsTrack.find_by(track: track2, song: song1)
        expect(songs_track2.previous_performance_gap).to eq(0)
        expect(songs_track2.next_performance_gap).to eq(0)
      end

      it "sets correct slugs for middle track" do
        service.call

        songs_track2 = SongsTrack.find_by(track: track2, song: song1)
        expect(songs_track2.previous_performance_slug).to eq("#{show.date}/#{track1.slug}")
        expect(songs_track2.next_performance_slug).to eq("#{show.date}/#{track3.slug}")
      end

      it "finds within-show performances correctly for last track" do
        service.call

        songs_track3 = SongsTrack.find_by(track: track3, song: song1)
        expect(songs_track3.previous_performance_gap).to eq(0)
        expect(songs_track3.previous_performance_slug).to eq("#{show.date}/#{track2.slug}")
      end
    end

    context "with tracks having multiple songs" do
      let!(:track) { create(:track, show:, position: 1, set: "1", songs: [ song1, song2 ]) }

      it "processes all songs in the track" do
        service.call

        songs_track1 = SongsTrack.find_by(track:, song: song1)
        songs_track2 = SongsTrack.find_by(track:, song: song2)

        expect(songs_track1).to be_present
        expect(songs_track2).to be_present
      end
    end

    context "with zero performance_gap_value shows" do
      let!(:current_track) { create(:track, show:, position: 4, set: "1", songs: [ song1 ]) }

      before do
        show1 = create(:show, date: "2023-06-15", venue:, tour:, performance_gap_value: 0)
        show2 = create(:show, date: "2023-06-01", venue:, tour:, performance_gap_value: 1)
        show3 = create(:show, date: "2023-08-01", venue:, tour:, performance_gap_value: 1)
        create(:track, show: show2, position: 1, set: "1", songs: [ song1 ])
        create(:track, show: show3, position: 1, set: "1", songs: [ song1 ])
      end

      it "excludes zero performance_gap_value shows from calculations" do
        service.call

        songs_track = SongsTrack.find_by(track: current_track, song: song1)
        expect(songs_track.previous_performance_gap).to eq(1)
        expect(songs_track.next_performance_gap).to eq(1)
      end
    end

    context "when update_previous is true" do
      let(:update_previous) { true }
      let!(:current_track) { create(:track, show:, position: 4, set: "1", songs: [ song1 ]) }
      let!(:earlier_show) { create(:show, date: "2023-06-01", venue:, tour:, performance_gap_value: 1) }
      let!(:earlier_track) { create(:track, show: earlier_show, position: 1, set: "1", songs: [ song1 ]) }

      before do
        show3 = create(:show, date: "2023-08-01", venue:, tour:, performance_gap_value: 1)
        create(:track, show: show3, position: 1, set: "1", songs: [ song1 ])
      end

      it "updates previous occurrences" do
        service.call

        earlier_songs_track = SongsTrack.find_by(track: earlier_track, song: song1)
        expect(earlier_songs_track.next_performance_gap).to eq(1)
        expect(earlier_songs_track.next_performance_slug).to eq("#{show.date}/#{current_track.slug}")
      end
    end

    context "with missing audio show" do
      let!(:show_without_audio) { create(:show, date: "2024-07-15", venue:, tour:, audio_status: "missing") }
      let!(:test_song) { create(:song, title: "Test Song") }
      let!(:missing_track) { create(:track, show: show_without_audio, position: 1, set: "1", songs: [ test_song ]) }

      before do
        show1 = create(:show, date: "2024-06-01", venue:, tour:, audio_status: "complete")
        show2 = create(:show, date: "2024-08-01", venue:, tour:, audio_status: "complete")
        create(:track, show: show1, position: 1, set: "1", songs: [ test_song ])
        create(:track, show: show2, position: 1, set: "1", songs: [ test_song ])
      end

      it "skips within-show audio calculations for missing audio shows" do
        described_class.call(show_without_audio)

        songs_track = SongsTrack.find_by(track: missing_track, song: test_song)
        expect(songs_track.previous_performance_gap_with_audio).to eq(1)
        expect(songs_track.next_performance_gap_with_audio).to eq(1)
      end
    end
  end

  describe "private methods" do
    let!(:track) { create(:track, show:, position: 1, set: "1", songs: [ song1 ]) }

    describe "#should_exclude_track?" do
      subject(:should_exclude) { service.send(:should_exclude_track?, track) }

      context "with regular track" do
        it { is_expected.to be false }
      end

      context "with track marked for exclusion" do
        let(:track) { create(:track, show:, position: 1, set: "1", songs: [ song1 ], exclude_from_performance_gaps: true) }

        it { is_expected.to be true }
      end

      context "with single excluded song" do
        let(:track) { create(:track, show:, position: 2, set: "1", songs: [ song3 ]) }

        it { is_expected.to be true }
      end

      context "with multiple songs including excluded" do
        let(:track) { create(:track, show:, position: 3, set: "1", songs: [ song1, song3 ]) }

        it { is_expected.to be false }
      end
    end

    describe "#should_exclude_song_from_gaps?" do
      subject(:should_exclude) { service.send(:should_exclude_song_from_gaps?, song) }

      context "with regular song" do
        let(:song) { song1 }

        it { is_expected.to be false }
      end

      context "with excluded song" do
        let(:song) { create(:song, title: "Banter") }

        it { is_expected.to be true }
      end
    end

    describe "#calculate_gap" do
      subject(:gap) { service.send(:calculate_gap, start_date, end_date, start_track, end_track) }

      let(:start_date) { Date.parse("2023-06-01") }
      let(:end_date) { Date.parse("2023-06-03") }
      let(:start_track) { nil }
      let(:end_track) { nil }

      context "with nil dates" do
        let(:start_date) { nil }

        it { is_expected.to be_nil }
      end

      context "with same dates" do
        let(:end_date) { start_date }

        it { is_expected.to eq(0) }
      end

      context "with consecutive dates" do
        it { is_expected.to eq(1) }
      end

      context "with same-show different performance units" do
        let(:end_date) { start_date }
        let(:start_track) { create(:track, show:, position: 11, set: "P", songs: [ song1 ]) }
        let(:end_track) { create(:track, show:, position: 12, set: "1", songs: [ song1 ]) }

        it { is_expected.to eq(1) }
      end

      context "with same-show same performance unit" do
        let(:end_date) { start_date }
        let(:start_track) { create(:track, show:, position: 13, set: "1", songs: [ song1 ]) }
        let(:end_track) { create(:track, show:, position: 14, set: "1", songs: [ song1 ]) }

        it { is_expected.to eq(0) }
      end
    end

    describe "#calculate_gap_with_audio" do
      subject(:gap) { service.send(:calculate_gap_with_audio, start_date, end_date, start_track, end_track) }

      let(:start_date) { Date.parse("2023-06-01") }
      let(:end_date) { Date.parse("2023-06-03") }
      let(:start_track) { nil }
      let(:end_track) { nil }

      before do
        create(:show, date: "2023-06-02", venue:, tour:, audio_status: "missing")
      end

      it "excludes missing audio shows from gap calculation" do
        expect(gap).to eq(1)
      end
    end

    describe "#different_performance_units?" do
      subject(:different_units) { service.send(:different_performance_units?, track1, track2) }

      let(:track1) { create(:track, show:, position: 15, set: "P", songs: [ song1 ]) }
      let(:track2) { create(:track, show:, position: 16, set: "1", songs: [ song1 ]) }

      context "with pre-show and main show tracks" do
        it { is_expected.to be true }
      end

      context "with two main show tracks" do
        let(:track1) { create(:track, show:, position: 17, set: "1", songs: [ song1 ]) }
        let(:track2) { create(:track, show:, position: 18, set: "2", songs: [ song1 ]) }

        it { is_expected.to be false }
      end

      context "with two pre-show tracks" do
        let(:track1) { create(:track, show:, position: 19, set: "P", songs: [ song1 ]) }
        let(:track2) { create(:track, show:, position: 20, set: "P", songs: [ song1 ]) }

        it { is_expected.to be false }
      end
    end

    describe "#build_slug" do
      subject(:slug) { service.send(:build_slug, track) }

      context "with valid track" do
        it { is_expected.to eq("#{show.date}/#{track.slug}") }
      end

      context "with nil track" do
        let(:track) { nil }

        it { is_expected.to be_nil }
      end
    end

    describe "#find_performance" do
      let!(:earlier_show) { create(:show, date: "2023-01-01", venue:, tour:) }
      let!(:later_show) { create(:show, date: "2023-12-01", venue:, tour:) }
      let!(:earlier_track) { create(:track, show: earlier_show, position: 1, set: "1", songs: [ song2 ]) }
      let!(:current_track) { create(:track, show:, position: 5, set: "1", songs: [ song2 ]) }
      let!(:later_track) { create(:track, show: later_show, position: 1, set: "1", songs: [ song2 ]) }

      context "when finding previous performance" do
        subject(:previous_performance) { service.send(:find_performance, song2, current_track, direction: :previous, audio_required: false) }

        it "finds the most recent previous performance" do
          expect(previous_performance).to eq(earlier_track)
          expect(previous_performance.songs).to include(song2)
        end
      end

      context "when finding next performance" do
        subject(:next_performance) { service.send(:find_performance, song2, current_track, direction: :next, audio_required: false) }

        it { is_expected.to eq(later_track) }
      end

      context "when finding previous performance with audio required" do
        subject(:previous_performance) { service.send(:find_performance, song2, current_track, direction: :previous, audio_required: true) }

        before do
          earlier_show.update!(audio_status: "missing")
        end

        it "finds no previous performance when audio is required but missing" do
          expect(previous_performance).to be_nil
        end
      end
    end

    describe "#find_tracks_within_show" do
      let!(:track1) { create(:track, show:, position: 6, set: "1", songs: [ song1 ]) }
      let!(:track2) { create(:track, show:, position: 7, set: "1", songs: [ song1 ]) }
      let!(:track3) { create(:track, show:, position: 8, set: "1", songs: [ song1 ]) }

      context "when finding previous track within show" do
        subject(:previous_track) { service.send(:find_tracks_within_show, song1, track2, :previous) }

        it { is_expected.to eq(track1) }
      end

      context "when finding next track within show" do
        subject(:next_track) { service.send(:find_tracks_within_show, song1, track2, :next) }

        it { is_expected.to eq(track3) }
      end
    end

    describe "#find_tracks_different_unit" do
      let!(:preshow_track) { create(:track, show:, position: 9, set: "P", songs: [ song1 ]) }
      let!(:main_track) { create(:track, show:, position: 10, set: "1", songs: [ song1 ]) }

      context "when finding main show track from pre-show" do
        subject(:main_track_found) { service.send(:find_tracks_different_unit, song1, preshow_track, :next) }

        it { is_expected.to eq(main_track) }
      end

      context "when finding pre-show track from main show" do
        subject(:preshow_track_found) { service.send(:find_tracks_different_unit, song1, main_track, :previous) }

        it { is_expected.to eq(preshow_track) }
      end
    end

    describe "#single_song_with_excluded_title?" do
      subject(:single_excluded) { service.send(:single_song_with_excluded_title?, track) }

      context "with single excluded song" do
        let(:track) { create(:track, show:, position: 21, set: "1", songs: [ song3 ]) }

        it { is_expected.to be true }
      end

      context "with single regular song" do
        let(:track) { create(:track, show:, position: 22, set: "1", songs: [ song1 ]) }

        it { is_expected.to be false }
      end

      context "with multiple songs including excluded" do
        let(:track) { create(:track, show:, position: 23, set: "1", songs: [ song1, song3 ]) }

        it { is_expected.to be false }
      end
    end

    describe "#count_performances_for_show" do
      subject(:count) { service.send(:count_performances_for_show, show) }

      context "with performance_gap_value of 1" do
        it { is_expected.to eq(1) }
      end

      context "with performance_gap_value of 2" do
        before { show.update!(performance_gap_value: 2) }

        it { is_expected.to eq(2) }
      end
    end
  end
end
