# frozen_string_literal: true
require 'rails_helper'

RSpec.describe SongsTrack do
  subject { build(:songs_track) }

  it { is_expected.to belong_to(:song) }
  it { is_expected.to belong_to(:track) }

  context 'callbacks' do
    let(:song) { build(:song) }
    subject { build(:songs_track, song: song) }

    it 'increments song track count on save' do
      subject.save
      expect(song.reload.tracks_count).to eq(1)
    end

    it 'decrements song track count on save' do
      subject.save
      subject.destroy
      expect(song.reload.tracks_count).to eq(0)
    end
  end

end
