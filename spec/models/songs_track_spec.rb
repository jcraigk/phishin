require 'rails_helper'

RSpec.describe SongsTrack do
  subject { build(:songs_track) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:song) }
  it { is_expected.to belong_to(:track) }

  it { is_expected.to validate_uniqueness_of(:song).scoped_to(:track_id) }

  describe 'callbacks' do
    subject(:songs_track) { build(:songs_track, song:) }

    let(:song) { build(:song) }

    it 'increments song track count on save' do
      songs_track.save
      expect(song.reload.tracks_count).to eq(1)
    end

    it 'decrements song track count on save' do
      songs_track.save
      songs_track.destroy
      expect(song.reload.tracks_count).to eq(0)
    end
  end

  describe 'touch behavior' do
    let(:track) { create(:track) }

    it 'touches the track when created' do
      track.update_column(:updated_at, 1.day.ago)
      create(:songs_track, track:)
      expect(track.reload.updated_at).to be > 1.minute.ago
    end

    it 'touches the track\'s show when created' do
      show = track.show
      show.update_column(:updated_at, 1.day.ago)
      create(:songs_track, track:)
      expect(show.reload.updated_at).to be > 1.minute.ago
    end

    it 'touches the track when destroyed' do
      songs_track = create(:songs_track, track:)
      track.update_column(:updated_at, 1.day.ago)
      songs_track.destroy
      expect(track.reload.updated_at).to be > 1.minute.ago
    end
  end
end
