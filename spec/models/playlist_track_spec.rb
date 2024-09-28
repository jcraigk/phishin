require 'rails_helper'

RSpec.describe PlaylistTrack, type: :model do
  subject { build(:playlist_track) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:playlist) }
  it { is_expected.to belong_to(:track) }

  it { is_expected.to validate_numericality_of(:position).only_integer }
  it { is_expected.to validate_uniqueness_of(:position).scoped_to(:playlist_id) }

  describe '#assign_duration' do
    let(:track) { create(:track, duration: 180000) } # Duration in milliseconds (3 minutes)
    let(:playlist) { create(:playlist) }

    context 'when both starts_at_second and ends_at_second are nil' do
      it 'assigns the full track duration to duration' do
        playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: nil, ends_at_second: nil)
        playlist_track.save
        expect(playlist_track.duration).to eq(track.duration)
      end
    end

    context 'when both starts_at_second and ends_at_second are set' do
      it 'calculates the excerpt duration' do
        playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: 30, ends_at_second: 60)
        playlist_track.save
        expect(playlist_track.duration).to eq(30000) # (60 - 30) * 1000
      end
    end

    context 'when only starts_at_second is set' do
      it 'calculates duration from start to the end of the track' do
        playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: 120, ends_at_second: nil)
        playlist_track.save
        expect(playlist_track.duration).to eq(60000) # 180000 - (120 * 1000)
      end
    end

    context 'when only ends_at_second is set' do
      it 'calculates duration from the beginning to the end second' do
        playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: nil, ends_at_second: 90)
        playlist_track.save
        expect(playlist_track.duration).to eq(90000) # 90 * 1000
      end
    end

    context 'when starts_at_second is greater than ends_at_second' do
      it 'sets duration to full track duration (invalid case)' do
        playlist_track = build(:playlist_track, track:, playlist:, starts_at_second: 120, ends_at_second: 60)
        playlist_track.save
        expect(playlist_track.duration).to eq(track.duration)
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
        playlist_track.update(starts_at_second: 30, ends_at_second: 60)
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
