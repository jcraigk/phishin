# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Track do
  subject { build(:track, title: 'Bathtub Gin') }

  it { is_expected.to have_many(:songs_tracks).dependent(:destroy) }
  it { is_expected.to have_many(:songs).through(:songs_tracks) }
  it { is_expected.to have_many(:likes).dependent(:destroy) }
  it { is_expected.to have_many(:track_tags).dependent(:destroy) }
  it { is_expected.to have_many(:tags).through(:track_tags) }
  it { is_expected.to have_many(:playlist_tracks).dependent(:destroy) }

  it { is_expected.to have_attached_file(:audio_file) }

  context 'friendly_id slugs' do
    let(:show) { create(:show) }
    let(:other_tracks) { create_list(:track, 2, title: 'Bathtub Gin', show: show) }

    it 'generates a slug from title (friendly_id), scoped to show' do
      subject.save
      expect(subject.slug).to eq('bathtub-gin')
      expect(other_tracks.first.slug).to eq('bathtub-gin')
      expect(other_tracks.second.slug).to match(
        /\Abathtub-gin-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      )
    end
  end

  context 'PgSearch kinda_matching title' do
    let!(:track1) { create(:track, title: 'Wolfman\'s Brother') }
    let!(:track2) { create(:track, title: 'Dire Wolf') }
    let!(:track3) { create(:track, title: 'Tube') }
    let!(:track4) { create(:track, title: 'First Tube') }

    it { is_expected.to be_a(PgSearch) }

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

  it 'validates >= 1 song associated' do
    subject.validate
    expect(subject.errors.keys).not_to include(:songs)
    subject.songs = []
    subject.validate
    expect(subject.errors.keys).to include(:songs)
  end

  context 'scopes' do
    context '#chronological', :timecop do
      let!(:track1) { create(:track, show: create(:show, date: 1.year.ago)) }
      let!(:track2) { create(:track, show: create(:show, date: 3.years.ago)) }
      let!(:track3) { create(:track, show: create(:show, date: 2.years.ago)) }

      it 'returns expected objects' do
        expect(described_class.chronological).to eq([track2, track3, track1])
      end
    end

    context '#tagged_with' do
      let!(:tracks) { create_list(:track, 2) }
      let(:tag) { create(:tag) }

      before { tracks.first.tags << tag }

      it 'returns expected objects' do
        expect(described_class.tagged_with(tag.name)).to eq([tracks.first])
      end
    end
  end

  context 'on create #save_duration' do
    before { subject.save }

    it 'updates the duration with that of the audio_file' do
      expect(subject.duration).to eq(2_011)
    end
  end

  it 'provides #set_name' do
    subject.set = nil
    expect(subject.set_name).to eq('Unknown Set')
    subject.set = 'S'
    expect(subject.set_name).to eq('Soundcheck')
    subject.set = 1
    expect(subject.set_name).to eq('Set 1')
    subject.set = 2
    expect(subject.set_name).to eq('Set 2')
    subject.set = 3
    expect(subject.set_name).to eq('Set 3')
    subject.set = 4
    expect(subject.set_name).to eq('Set 4')
    subject.set = 'E'
    expect(subject.set_name).to eq('Encore')
    subject.set = 'E2'
    expect(subject.set_name).to eq('Encore 2')
    subject.set = 'E3'
    expect(subject.set_name).to eq('Encore 3')
  end

  context 'mp3 tagging' do
    # TODO: test save_default_id3_tags
  end

  context '#generic_slug' do
    it 'slugifies the title' do
      subject.title = '<>=Bathtub !!Gin<>'
      expect(subject.generic_slug).to eq('bathtub-gin')
    end

    it 'shortens long titles according to prescriptive rules' do
      subject.title = 'Hold Your Head Up'
      expect(subject.generic_slug).to eq('hyhu')
      subject.title = 'The Man Who Stepped Into Yesterday'
      expect(subject.generic_slug).to eq('tmwsiy')
      subject.title = 'She Caught the Katy and Left Me a Mule to Ride'
      expect(subject.generic_slug).to eq('she-caught-the-katy')
      subject.title = 'McGrupp and the Watchful Hosemasters'
      expect(subject.generic_slug).to eq('mcgrupp')
      subject.title = 'Big Black Furry Creature from Mars'
      expect(subject.generic_slug).to eq('bbfcfm')
    end
  end

  it 'provides #mp3_url' do
    subject.id = 123_456_789
    expect(subject.mp3_url).to eq('http://localhost/audio/123/456/789/123456789.mp3')
  end

  context 'serialization' do
    subject { create(:track) }

    it 'provides #as_json' do
      expect(subject.as_json).to eq(
        id: subject.id,
        title: subject.title,
        position: subject.position,
        duration: subject.duration,
        set: subject.set,
        set_name: subject.set_name,
        likes_count: subject.likes_count,
        slug: subject.slug,
        mp3: subject.mp3_url,
        song_ids: subject.songs.map(&:id),
        updated_at: subject.updated_at.to_s
      )
    end

    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        id: subject.id,
        show_id: subject.show.id,
        show_date: subject.show.date.to_s,
        title: subject.title,
        position: subject.position,
        duration: subject.duration,
        set: subject.set,
        set_name: subject.set_name,
        likes_count: subject.likes_count,
        slug: subject.slug,
        tags: subject.tags.sort_by(&:priority).map(&:name).as_json,
        mp3: subject.mp3_url,
        song_ids: subject.songs.map(&:id),
        updated_at: subject.updated_at.to_s
      )
    end
  end
end
