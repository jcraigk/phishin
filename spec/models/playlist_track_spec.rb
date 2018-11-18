# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PlaylistTrack do
  subject { FactoryBot.build(:playlist_track) }

  it { is_expected.to belong_to(:playlist) }
  it { is_expected.to belong_to(:track) }

  # it { is_expected.to validate_numericality_of(:position) }

  context 'serialization' do
    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        position: subject.position,
        id: subject.track_id,
        show_id: subject.track.show_id,
        show_date: subject.track.show.date,
        title: subject.track.title,
        duration: subject.track.duration,
        set: subject.track.set,
        set_name: subject.track.set_name,
        likes_count: subject.track.likes_count,
        slug: subject.track.slug,
        tags: subject.track.tags.sort_by(&:priority).map(&:name).as_json,
        mp3: subject.track.mp3_url,
        song_ids: subject.track.songs.map(&:id)
      )
    end
  end
end
