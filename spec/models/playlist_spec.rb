# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Playlist do
  subject { build(:playlist, :with_tracks) }

  it { is_expected.to have_many(:tracks) }
  it { is_expected.to have_many(:playlist_tracks) }
  it { is_expected.to have_many(:playlist_bookmarks) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }

  it 'provides #as_json_api' do
    expect(subject.as_json_api).to eq(
      slug: subject.slug,
      name: subject.name,
      duration: subject.duration,
      tracks: subject.playlist_tracks.order(:position).map(&:as_json_api),
      updated_at: subject.updated_at
    )
  end

  it 'provides #as_json_api_basic' do
    expect(subject.as_json_api_basic).to eq(
      slug: subject.slug,
      name: subject.name,
      duration: subject.duration,
      track_count: subject.playlist_tracks.size,
      updated_at: subject.updated_at
    )
  end
end
