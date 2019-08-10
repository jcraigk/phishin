# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Song do
  subject(:song) { create(:song, title: 'Bathtub Gin') }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:songs_tracks).dependent(:destroy) }
  it { is_expected.to have_many(:tracks).through(:songs_tracks) }

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_uniqueness_of(:title) }
  it { is_expected.to validate_uniqueness_of(:alias).allow_nil }

  it 'generates a slug from title (friendly_id)' do
    song.save
    expect(song.slug).to eq('bathtub-gin')
  end

  describe 'PgSearch::Model kinda_matching title' do
    let!(:song1) { create(:song, title: 'Wolfman\'s Brother') }
    let!(:song2) { create(:song, title: 'Dire Wolf') }
    let!(:song3) { create(:song, title: 'Tube') }
    let!(:song4) { create(:song, title: 'First Tube') }

    it { is_expected.to be_a(PgSearch::Model) }

    it 'matches `Woflman`' do
      expect(described_class.kinda_matching('Wolfman')).to eq([song1])
    end

    it 'matches `Wolf`' do
      expect(described_class.kinda_matching('Wolf')).to eq([song2])
    end

    it 'matches `Tube`' do
      expect(described_class.kinda_matching('Tube')).to match_array([song3, song4])
    end
  end

  describe '#title_starting_with' do
    let!(:a_song) { create(:song, title: 'Access Me') }
    let!(:num_song) { create(:song, title: '555') }

    before do
      create(:song, title: 'Bathtub Gin') # Starts with `B`
    end

    it 'returns records starting with `A`' do
      expect(described_class.title_starting_with('a')).to eq([a_song])
    end

    it 'returns records starting with a number' do
      expect(described_class.title_starting_with('#')).to eq([num_song])
    end
  end

  describe '#with_lyrical_excerpt' do
    let!(:song_with_excerpt) do
      create(:song, lyrical_excerpt: 'An asteroid crashed and nothing burned')
    end

    before do
      create_list(:song, 2) # songs with no excerpt
    end

    it 'returns the lyrical excerpt' do
      expect(described_class.with_lyrical_excerpt).to eq([song_with_excerpt])
    end
  end

  describe 'serialization' do
    subject(:song) { create(:song, :with_tracks) }

    let(:expected_as_json) do
      {
        id: song.id,
        title: song.title,
        alias: song.alias,
        tracks_count: song.tracks_count,
        slug: song.slug,
        updated_at: song.updated_at.iso8601
      }
    end
    let(:expected_as_json_api) do
      {
        id: song.id,
        title: song.title,
        alias: song.alias,
        tracks_count: song.tracks_count,
        slug: song.slug,
        updated_at: song.updated_at.iso8601,
        tracks: song.tracks.sort_by { |t| t.show.date }.map(&:as_json_api)
      }
    end

    it 'provides #as_json' do
      expect(song.as_json).to eq(expected_as_json)
    end

    it 'provides #as_json_api' do
      expect(song.as_json_api).to eq(expected_as_json_api)
    end
  end
end
