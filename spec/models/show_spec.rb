# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Show do
  subject { create(:show) }

  it { is_expected.to belong_to(:tour) }
  it { is_expected.to belong_to(:venue) }

  it { is_expected.to have_many(:tracks).dependent(:destroy) }
  it { is_expected.to have_many(:likes).dependent(:destroy) }
  it { is_expected.to have_many(:show_tags).dependent(:destroy) }
  it { is_expected.to have_many(:tags) }

  it { is_expected.to validate_presence_of(:date) }
  it { is_expected.to validate_uniqueness_of(:date) }

  it { is_expected.to delegate_method(:name).to(:tour).with_prefix }

  describe '#cache_venue_name' do
    let(:venue) { create(:venue) }
    let(:date) { '2018-01-01' }
    let(:show) { build(:show, venue: venue, date: date) }

    context 'when there are no venue renames' do
      it 'caches the venue name before validation' do
        show.validate
        expect(show.venue_name).to eq(venue.name)
      end
    end

    context 'when there is a venue rename in the past' do
      let!(:venue_rename) { create(:venue_rename, venue: venue, renamed_on: Date.parse('2018-01-01') - 1.day) }

      it 'caches the latest venue rename before validation' do
        show.validate
        expect(show.venue_name).to eq(venue_rename.name)
      end
    end
  end

  describe 'scopes' do
    describe 'default scope' do
      let!(:show1) { create(:show, published: false) }
      let!(:show2) { create(:show, published: true) }
      let!(:show3) { create(:show, published: true) }

      it 'returns published shows' do
        expect(described_class.order(date: :asc)).to match_array([show2, show3])
      end
    end

    describe '#between_years' do
      let!(:show1) { create(:show, date: '2014-10-31') }
      let!(:show2) { create(:show, date: '2015-01-01') }
      let!(:show3) { create(:show, date: '2016-01-01') }
      let!(:show4) { create(:show, date: '2017-01-01') }

      it 'returns expected objects' do
        expect(described_class.between_years(2014, 2015)).to eq([show1, show2])
      end
    end

    describe '#during_year' do
      let!(:show1) { create(:show, date: '2014-10-31') }
      let!(:show2) { create(:show, date: '2015-01-01') }

      it 'returns expected objects' do
        expect(described_class.during_year(2014)).to eq([show1])
      end
    end

    describe '#on_day_of_year' do
      let!(:show1) { create(:show, date: '2018-10-31') }
      let!(:show2) { create(:show, date: '2018-01-01') }

      it 'returns expected object' do
        expect(described_class.on_day_of_year(10, 31)).to eq([show1])
      end
    end

    describe '#random' do
      xit 'returns random record' do
      end
    end

    describe '#tagged_with' do
      let!(:shows) { create_list(:show, 2) }
      let(:tag) { create(:tag) }

      before { shows.first.tags << tag }

      it 'returns expected objects' do
        expect(described_class.tagged_with(tag.name)).to eq([shows.first])
      end
    end
  end

  it 'provides #date_with_dots' do
    expect(subject.date_with_dots).to eq(subject.date.strftime('%Y.%m.%d'))
  end

  context '#save_duration' do
    subject { create(:show, :with_tracks) }

    let(:track_sum) { subject.tracks.map(&:duration).inject(0, &:+) }

    it 'updates the duration with the sum of all tracks' do
      expect(subject.duration).not_to eq(track_sum)
      subject.save_duration
      expect(subject.duration).to eq(track_sum)
    end
  end

  describe 'serialization' do
    it 'provides #as_json' do
      expect(subject.as_json).to eq(
        id: subject.id,
        date: subject.date.iso8601,
        duration: subject.duration,
        incomplete: subject.incomplete,
        sbd: subject.sbd,
        remastered: subject.remastered,
        tour_id: subject.tour_id,
        venue_id: subject.venue_id,
        likes_count: subject.likes_count,
        taper_notes: subject.taper_notes,
        updated_at: subject.updated_at.iso8601,
        venue_name: subject.venue&.name,
        location: subject.venue&.location
      )
    end

    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        id: subject.id,
        date: subject.date.iso8601,
        duration: subject.duration,
        incomplete: subject.incomplete,
        sbd: subject.sbd,
        remastered: subject.remastered,
        tags: subject.tags.sort_by(&:priority).map(&:name).as_json,
        tour_id: subject.tour_id,
        venue: subject.venue.as_json,
        venue_name: subject.venue_name,
        taper_notes: subject.taper_notes,
        likes_count: subject.likes_count,
        tracks: subject.tracks.sort_by(&:position).map(&:as_json_api),
        updated_at: subject.updated_at.iso8601
      )
    end
  end
end
