# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Song do
  subject { build(:song, title: 'First Tube') }

  it { is_expected.to have_and_belong_to_many(:tracks) }

  it 'generates a slug from title (friendly_id)' do
    subject.save
    expect(subject.slug).to eq('first-tube')
  end

  context 'PgSearch kinda_matching title' do
    let!(:song1) { create(:song, title: 'Wolfman\'s Brother') }
    let!(:song2) { create(:song, title: 'Dire Wolf') }
    let!(:song3) { create(:song, title: 'Tube') }
    let!(:song4) { create(:song, title: 'First Tube') }

    it { is_expected.to be_a(PgSearch) }

    it 'returns expected results' do
      expect(described_class.kinda_matching('Wolfman')).to eq([song1])
      expect(described_class.kinda_matching('Wolf')).to eq([song2])
      expect(described_class.kinda_matching('Tube')).to match_array([song3, song4])
    end
  end

  context 'scopes' do
    context '#relevant' do
      let!(:songs_with_tracks) { create_list(:song, 2, :with_tracks) }
      let!(:song_with_alias) { create(:song, alias_for: songs_with_tracks.first.id) }
      let!(:irrelevant_song) { create(:song) }

      it 'returns expected objects' do
        expect(described_class.relevant).to match_array(songs_with_tracks + [song_with_alias])
      end
    end

    context '#title_starting_with' do
      let!(:a_song) { create(:song, title: 'Access Me') }
      let!(:b_song) { create(:song, title: 'Bathtub Gin') }
      let!(:num_song) { create(:song, title: '555') }

      it 'returns expected objects' do
        expect(described_class.title_starting_with('a')).to eq([a_song])
        expect(described_class.title_starting_with('#')).to eq([num_song])
      end
    end

    context '#with_lyrical_excerpt' do
      let!(:songs_without_excerpt) { create_list(:song, 2) }
      let!(:song_with_excerpt) { create(:song, lyrical_excerpt: 'An asteroid crashed and nothing burned') }

      it 'returns the lyrical excerpt' do
        expect(described_class.with_lyrical_excerpt).to eq([song_with_excerpt])
      end
    end
  end

  context 'aliasing' do
    let(:alias_song) { create(:song, alias_for: song.id) }
    let(:song) { create(:song) }

    it 'provides #alias?' do
      expect(song.alias?).to eq(false)
      expect(alias_song.alias?).to eq(true)
    end

    it 'provides #aliased_song' do
      expect(alias_song.aliased_song).to eq(song)
    end
  end

  context 'serialization' do
    subject { create(:song, :with_tracks) }

    it 'provides #as_json' do
      expect(subject.as_json).to eq(
        id: subject.id,
        title: subject.title,
        alias_for: subject.alias_for,
        tracks_count: subject.tracks_count,
        slug: subject.slug,
        updated_at: subject.updated_at
      )
    end

    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        id: subject.id,
        title: subject.title,
        alias_for: subject.alias_for,
        tracks_count: subject.tracks_count,
        slug: subject.slug,
        updated_at: subject.updated_at,
        tracks: subject.tracks.sort_by { |t| t.show.date }.map do |t|
          {
            id: t.id,
            title: t.title,
            duration: t.duration,
            show_id: t.show.id,
            show_date: t.show.date,
            set: t.set,
            position: t.position,
            likes_count: t.likes_count,
            slug: t.slug,
            mp3: t.mp3_url
          }
        end
      )
    end
  end
end
