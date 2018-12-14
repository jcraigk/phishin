# frozen_string_literal: true
require 'rails_helper'

RSpec.describe SongsTrack do
  subject { build(:songs_track) }

  it { is_expected.to belong_to(:song) }
  it { is_expected.to belong_to(:track) }

  it { is_expected.to validate_uniqueness_of(:song).scoped_to(:track_id) }

  describe 'callbacks' do
    subject(:songs_track) { build(:songs_track, song: song) }

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
end
