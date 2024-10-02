require 'rails_helper'

RSpec.describe PlaylistTrack do
  subject { build(:playlist_track) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:playlist).counter_cache(:tracks_count) }
  it { is_expected.to belong_to(:track) }

  it { is_expected.to validate_numericality_of(:position).only_integer }
  it { is_expected.to validate_uniqueness_of(:position).scoped_to(:playlist_id) }

  describe 'callbacks' do
    describe '#assign_duration' do
      let(:track) { create(:track, duration: 18000) }
      let(:playlist) { create(:playlist) }

      context 'when both starts_at_second and ends_at_second are nil' do
        it 'assigns the full track duration to duration' do
          playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: nil,
ends_at_second: nil)
          playlist_track.save
          expect(playlist_track.duration).to eq(track.duration)
        end
      end

      context 'when both starts_at_second and ends_at_second are set within track duration' do
        it 'calculates the excerpt duration based on their difference' do
          playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: 3,
ends_at_second: 5)
          playlist_track.save
          expect(playlist_track.duration).to eq(2000) # (5 - 3) * 1000
        end
      end

      context 'when only starts_at_second is set and is within the track duration' do
        it 'calculates duration from start to the end of the track' do
          playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: 10,
ends_at_second: nil)
          playlist_track.save
          expect(playlist_track.duration).to eq(8000) # 18000 - (10 * 1000)
        end
      end

      context 'when only ends_at_second is set and is within the track duration' do
        it 'calculates duration from the beginning to the end second' do
          playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: nil,
ends_at_second: 12)
          playlist_track.save
          expect(playlist_track.duration).to eq(12000) # 12 * 1000
        end
      end

      context 'when starts_at_second is greater than ends_at_second' do
        it 'sets duration to full track duration (invalid case)' do
          playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: 15,
ends_at_second: 10)
          playlist_track.save
          expect(playlist_track.duration).to eq(track.duration)
        end
      end

      context 'when starts_at_second and ends_at_second are negative' do
        it 'assigns the full track duration' do
          playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: -1,
ends_at_second: -1)
          playlist_track.save
          expect(playlist_track.duration).to eq(track.duration)
        end
      end

      context 'when starts_at_second and ends_at_second are beyond the track duration' do
        it 'calculates based on their difference' do
          playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: 25,
ends_at_second: 30)
          playlist_track.save
          expect(playlist_track.duration).to eq(5000) # (30 - 25) * 1000
        end
      end
    end

    describe '#update_playlist_duration' do
      let(:playlist) { create(:playlist) }

      describe 'after create' do
        it 'calls update_duration on the parent playlist' do
          playlist_track = build(:playlist_track, playlist:)
          expect(playlist).to receive(:update_duration)
          playlist_track.save
        end
      end

      describe 'after update' do
        it 'calls update_duration on the parent playlist' do
          playlist_track = create(:playlist_track, playlist:)
          expect(playlist).to receive(:update_duration)
          playlist_track.update(starts_at_second: 3, ends_at_second: 5)
        end
      end

      describe 'after destroy' do
        it 'calls update_duration on the parent playlist' do
          playlist_track = create(:playlist_track, playlist:)
          expect(playlist).to receive(:update_duration)
          playlist_track.destroy
        end
      end
    end
  end

  describe '#excerpt_duration' do
    let(:track) { create(:track, duration: 20000) } # Track duration set to 20 seconds
    let(:playlist) { create(:playlist) }

    context 'when both start and end are zero' do
      it 'returns full duration' do
        playlist_track = build(:playlist_track, track:, starts_at_second: 0, ends_at_second: 0)
        expect(playlist_track.send(:excerpt_duration)).to eq(track.duration)
      end
    end

    context 'when start is before end' do
      it 'returns duration between start and end' do
        playlist_track = build(:playlist_track, track:, starts_at_second: 5, ends_at_second: 8)
        expect(playlist_track.send(:excerpt_duration)).to eq(3000) # (8 - 5) * 1000
      end
    end

    context 'when start is set but end is zero' do
      it 'returns duration from start to end of track' do
        playlist_track = build(:playlist_track, track:, starts_at_second: 12, ends_at_second: 0)
        expect(playlist_track.send(:excerpt_duration)).to eq(8000) # 20000 - (12 * 1000)
      end
    end

    context 'when end is set but start is zero' do
      it 'returns duration from start of track to end' do
        playlist_track = build(:playlist_track, track:, starts_at_second: 0, ends_at_second: 4)
        expect(playlist_track.send(:excerpt_duration)).to eq(4000) # 4 * 1000
      end
    end

    context 'when start is after end' do
      it 'returns full duration' do
        playlist_track = build(:playlist_track, track:, starts_at_second: 15, ends_at_second: 10)
        expect(playlist_track.send(:excerpt_duration)).to eq(track.duration)
      end
    end

    context 'when duration is negative' do
      it 'returns full duration' do
        playlist_track = build(:playlist_track, track:, starts_at_second: -1, ends_at_second: -1)
        expect(playlist_track.send(:excerpt_duration)).to eq(track.duration)
      end
    end
  end
end
