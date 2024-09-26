require 'rails_helper'

RSpec.describe Playlist do
  subject { build(:playlist) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:tracks) }
  it { is_expected.to have_many(:playlist_tracks) }
  it { is_expected.to have_many(:likes).dependent(:destroy) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:slug) }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_uniqueness_of(:slug) }
  it { is_expected.to allow_values('Harpu', 'This is a longer name').for(:name) }
  it { is_expected.to validate_length_of(:description).is_at_most(500) }

  it do
    is_expected
      .not_to allow_value('H', 'this is a longer name this is a longer name this is a')
      .for(:name)
  end

  it { is_expected.to allow_values('harpu', 'this-is-a-longer-name').for(:slug) }

  it do
    is_expected
      .not_to allow_value('h', 'this-is-a-longer-name-this-is-a-longer-name-this-is-a')
      .for(:slug)
  end

  describe 'serialization' do
    let(:playlist) { create(:playlist) }
    let(:expected_as_json_api_basic) do
      {
        slug: playlist.slug,
        name: playlist.name,
        duration: playlist.duration,
        track_count: playlist.playlist_tracks.size,
        updated_at: playlist.updated_at.iso8601
      }
    end
    let(:expected_as_json_api) do
      {
        slug: playlist.slug,
        name: playlist.name,
        duration: playlist.duration,
        tracks: playlist.playlist_tracks.order(:position).map { |x| x.track.as_json_api },
        updated_at: playlist.updated_at.iso8601
      }
    end

    it 'provides #as_json_api' do
      expect(playlist.as_json_api).to eq(expected_as_json_api)
    end

    it 'provides #as_json_api_basic' do
      expect(playlist.as_json_api_basic).to eq(expected_as_json_api_basic)
    end
  end
end
