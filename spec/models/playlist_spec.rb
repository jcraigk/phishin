require 'rails_helper'

RSpec.describe Playlist do
  subject { build(:playlist) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:tracks) }
  it { is_expected.to have_many(:playlist_tracks).dependent(:destroy) }
  it { is_expected.to have_many(:likes).dependent(:destroy) }
  it { is_expected.to belong_to(:user) }

  it { is_expected.to accept_nested_attributes_for(:playlist_tracks).allow_destroy(true) }

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

  describe 'validations' do
    # Commented out because of `Too many open files @ rb_sysopen`
    # it 'validates tracks count within limit' do
    #   playlist = build(:playlist, playlist_tracks: build_list(:playlist_track, 251))
    #   expect(playlist).not_to be_valid
    #  expect(playlist.errors[:tracks]).to include("can't number more than #{Playlist::MAX_TRACKS}")
    # end

    it 'validates tracks count above minimum' do
      playlist = build(:playlist, playlist_tracks: build_list(:playlist_track, 1))
      expect(playlist).not_to be_valid
      expect(playlist.errors[:tracks]).to include("must number at least 2")
    end
  end

  describe 'scopes' do
    it '.published returns only published playlists' do
      create(:playlist, published: true)
      create(:playlist, published: false)
      expect(Playlist.published.count).to eq(1)
    end
  end

  describe 'callbacks' do
    it 'updates duration after save' do
      playlist = create(:playlist, tracks_count: 3)
      expect(playlist.duration).to eq(450000)
    end
  end

  describe '#update_duration' do
    let!(:playlist) { create(:playlist, tracks_count: 3) }

    it 'updates the playlist duration after adding tracks' do
      playlist.reload
      expect(playlist.duration).to eq(450000)
    end

    it 'updates the playlist duration after removing a track' do
      playlist.playlist_tracks.first.destroy
      playlist.reload
      expect(playlist.duration).to eq(300000)
    end

    it 'updates the playlist duration after changing a track excerpt' do
      playlist_track = playlist.playlist_tracks.first
      playlist_track.update(starts_at_second: 60, ends_at_second: 120) # Invalid but doesn't matter
      playlist.reload
      expect(playlist.duration).to eq(360000)
    end
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
