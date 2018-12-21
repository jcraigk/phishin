# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Venue do
  subject(:venue) { create(:venue, name: 'Madison Square Garden') }

  it { is_expected.to have_many(:shows) }
  it { is_expected.to have_many(:venue_renames).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:city) }
  it { is_expected.to validate_presence_of(:city) }
  it { is_expected.to validate_presence_of(:country) }

  describe '#should_generate_new_friendly_id' do
    before { venue.update(name: 'New Name') }

    it 'generates a new slug' do
      expect(venue.reload.slug).to eq('new-name')
    end
  end

  it 'generates a slug from name (friendly_id)' do
    venue.save
    expect(venue.slug).to eq('madison-square-garden')
  end

  # geocoded_by :address
  it 'responds to geocode' do
    expect(venue).to respond_to(:geocode)
  end

  describe 'scopes' do
    describe '#name_starting_with' do
      let!(:a_venue) { create(:venue, name: 'Allstate Arena') }
      let!(:b_venue) { create(:venue, name: 'BlueCross Arena') }
      let!(:num_venue) { create(:venue, name: '13x13 Club') }

      it 'returns expected objects' do
        expect(described_class.name_starting_with('a')).to eq([a_venue])
        expect(described_class.name_starting_with('#')).to eq([num_venue])
      end
    end
  end

  describe '#long_name' do
    subject { build(:venue, name: 'Madison Square Garden', abbrev: 'MSG') }

    let!(:venue_rename) { create(:venue_rename, name: 'The Dump', venue: subject) }

    it 'returns long name' do
      expect(subject.long_name).to eq('Madison Square Garden (MSG) (aka The Dump)')
    end
  end

  describe '#location' do
    subject do
      build(
        :venue,
        city: 'Miami',
        state: 'FL',
        country: 'USA'
      )
    end

    it 'returns expected location strings' do
      expect(subject.location).to eq('Miami, FL')
      subject.country = 'Russia'
      expect(subject.location).to eq('Miami, FL, Russia')
      subject.state = nil
      expect(subject.location).to eq('Miami, Russia')
    end
  end

  context 'when serializing' do
    subject { create(:venue, :with_shows) }

    it 'provides #as_json' do
      expect(subject.as_json).to eq(
        id: subject.id,
        name: subject.name,
        other_names: subject.other_names,
        latitude: subject.latitude.round(6),
        longitude: subject.longitude.round(6),
        shows_count: subject.shows_count,
        location: subject.location,
        slug: subject.slug,
        updated_at: subject.updated_at.iso8601
      )
    end

    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        id: subject.id,
        name: subject.name,
        other_names: subject.other_names,
        latitude: subject.latitude.round(6),
        longitude: subject.longitude.round(6),
        shows_count: subject.shows_count,
        location: subject.location,
        city: subject.city,
        state: subject.state,
        country: subject.country,
        slug: subject.slug,
        show_dates: subject.shows.order(date: :asc).map(&:date).map(&:iso8601),
        show_ids: subject.shows.order(date: :asc).map(&:id),
        updated_at: subject.updated_at.iso8601
      )
    end
  end
end
