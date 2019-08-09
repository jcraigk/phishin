# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Track do
  subject(:track) { create(:track, title: 'Bathtub Gin') }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:songs_tracks).dependent(:destroy) }
  it { is_expected.to have_many(:songs).through(:songs_tracks) }
  it { is_expected.to have_many(:likes).dependent(:destroy) }
  it { is_expected.to have_many(:track_tags).dependent(:destroy) }
  it { is_expected.to have_many(:tags).through(:track_tags) }
  it { is_expected.to have_many(:playlist_tracks).dependent(:destroy) }

  it { is_expected.to have_attached_file(:audio_file) }

  describe 'slug generation' do
    let(:slug) { 'new-slug' }
    let(:mock_generator) { instance_double(TrackSlugGenerator) }

    before do
      allow(TrackSlugGenerator).to receive(:new).and_return(mock_generator)
      allow(mock_generator).to receive(:call).and_return(slug)
      track.save
    end

    it 'assigns slug from TrackSlugGenerator' do
      expect(TrackSlugGenerator).to have_received(:new).with(track)
      expect(mock_generator).to have_received(:call)
      expect(track.slug).to eq(slug)
    end
  end

  describe 'PgSearch::Model kinda_matching title' do
    let!(:track1) { create(:track, title: 'Wolfman\'s Brother') }
    let!(:track2) { create(:track, title: 'Dire Wolf') }
    let!(:track3) { create(:track, title: 'Tube') }
    let!(:track4) { create(:track, title: 'First Tube') }

    it { is_expected.to be_a(PgSearch::Model) }

    it 'returns expected results' do
      expect(described_class.kinda_matching('Wolfman')).to eq([track1])
      expect(described_class.kinda_matching('Wolf')).to eq([track2])
      expect(described_class.kinda_matching('Tube')).to match_array([track3, track4])
    end
  end

  it { is_expected.to validate_presence_of(:show) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_presence_of(:set) }
  it { is_expected.to validate_uniqueness_of(:position).scoped_to(:show_id) }

  it 'provides #url' do
    expect(track.url).to eq("#{APP_BASE_URL}/#{track.show.date.to_s(:db)}/#{track.slug}")
  end

  it 'validates >= 1 song associated' do
    track.validate
    expect(track.errors.keys).not_to include(:songs)
    track.songs = []
    track.validate
    expect(track.errors.keys).to include(:songs)
  end

  describe 'scopes' do
    describe '#chronological', :timecop do
      let!(:track1) { create(:track, show: create(:show, date: 1.year.ago)) }
      let!(:track2) { create(:track, show: create(:show, date: 3.years.ago)) }
      let!(:track3) { create(:track, show: create(:show, date: 2.years.ago)) }

      it 'returns expected objects' do
        expect(described_class.chronological).to eq([track2, track3, track1])
      end
    end

    describe '#tagged_with' do
      let!(:tracks) { create_list(:track, 2) }
      let(:tag) { create(:tag) }

      before { tracks.first.tags << tag }

      it 'returns expected objects' do
        expect(described_class.tagged_with(tag.slug)).to eq([tracks.first])
      end
    end
  end

  context 'when creating the record' do
    before { track.save }

    it 'updates the duration with that of audio_file' do
      expect(track.duration).to eq(2_011)
    end
  end

  describe '#set_name' do
    it 'recognizes nil' do
      track.set = nil
      expect(track.set_name).to eq('Unknown Set')
    end

    it 'recognizes `S`' do
      track.set = 'S'
      expect(track.set_name).to eq('Soundcheck')
    end

    it 'recognizes `1`' do
      track.set = '1'
      expect(track.set_name).to eq('Set 1')
    end

    it 'recognizes `2`' do
      track.set = '2'
      expect(track.set_name).to eq('Set 2')
    end

    it 'recognizes `3`' do
      track.set = '3'
      expect(track.set_name).to eq('Set 3')
    end

    it 'recognizes `4`' do
      track.set = '4'
      expect(track.set_name).to eq('Set 4')
    end

    it 'recognizes `E`' do
      track.set = 'E'
      expect(track.set_name).to eq('Encore')
    end

    it 'recognizes `E2`' do
      track.set = 'E2'
      expect(track.set_name).to eq('Encore 2')
    end

    it 'recognizes `E3`' do
      track.set = 'E3'
      expect(track.set_name).to eq('Encore 3')
    end
  end

  describe 'ID3 tagging' do
    let(:mock_tagger) { instance_double(Id3Tagger) }

    before do
      allow(Id3Tagger).to receive(:new).and_return(mock_tagger)
      allow(mock_tagger).to receive(:call).and_return(true)
      track.apply_id3_tags
    end

    it 'calls Id3Tagger' do
      expect(Id3Tagger).to have_received(:new).with(track)
      expect(mock_tagger).to have_received(:call)
    end
  end

  it 'provides #mp3_url' do
    track.id = 123_456_789
    expect(track.mp3_url).to eq('http://localhost/audio/123/456/789/123456789.mp3')
  end

  describe 'serialization' do
    let!(:track_tags) { create_list(:track_tag, 3, track: track) }
    let(:expected_as_json) do
      {
        id: track.id,
        title: track.title,
        position: track.position,
        duration: track.duration,
        jam_starts_at_second: track.jam_starts_at_second,
        set: track.set,
        set_name: track.set_name,
        likes_count: track.likes_count,
        slug: track.slug,
        mp3: track.mp3_url,
        song_ids: track.songs.map(&:id),
        updated_at: track.updated_at.iso8601
      }
    end
    let(:tags) do
      track_tags.map do |track_tag|
        {
          id: track_tag.tag.id,
          name: track_tag.tag.name,
          priority: track_tag.tag.priority,
          group: track_tag.tag.group,
          color: track_tag.tag.color,
          notes: track_tag.notes,
          transcript: track_tag.transcript,
          starts_at_second: track_tag.starts_at_second,
          ends_at_second: track_tag.ends_at_second
        }
      end
    end
    let(:expected_as_json_api) do
      {
        id: track.id,
        show_id: track.show.id,
        show_date: track.show.date.iso8601,
        title: track.title,
        position: track.position,
        duration: track.duration,
        jam_starts_at_second: track.jam_starts_at_second,
        set: track.set,
        set_name: track.set_name,
        likes_count: track.likes_count,
        slug: track.slug,
        tags: tags.sort_by { |t| t[:priority] },
        mp3: track.mp3_url,
        song_ids: track.songs.map(&:id),
        updated_at: track.updated_at.iso8601
      }
    end

    it 'provides #as_json' do
      expect(track.as_json).to eq(expected_as_json)
    end

    it 'provides #as_json_api' do
      expect(track.as_json_api).to eq(expected_as_json_api)
    end
  end
end
