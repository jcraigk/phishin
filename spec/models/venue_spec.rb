# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Venue do
  subject(:venue) { create(:venue, name: 'Madison Square Garden') }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:shows).dependent(:nullify) }
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
      let!(:num_venue) { create(:venue, name: '13x13 Club') }

      before { create(:venue, name: 'BlueCross Arena') }

      it 'returns expected records starting with `A`' do
        expect(described_class.name_starting_with('a')).to eq([a_venue])
      end

      it 'returns expected records starting with a number' do
        expect(described_class.name_starting_with('#')).to eq([num_venue])
      end
    end
  end

  describe '#long_name' do
    subject(:venue) { build(:venue, name: 'Madison Square Garden', abbrev: 'MSG') }

    before do
      create(:venue_rename, name: 'The Dump', venue:)
    end

    it 'returns long name' do
      expect(venue.long_name).to eq('Madison Square Garden (MSG) (aka The Dump)')
    end
  end

  describe '#location' do
    subject(:venue) { build(:venue, city: 'Miami', state: 'FL', country: 'USA') }

    it 'returns expected full string' do
      expect(venue.location).to eq('Miami, FL')
    end

    it 'includes country when not USA' do
      venue.country = 'Russia'
      expect(venue.location).to eq('Miami, FL, Russia')
    end

    it 'excludes state when not present' do
      venue.country = 'Russia'
      venue.state = nil
      expect(venue.location).to eq('Miami, Russia')
    end
  end

  context 'when serializing' do
    subject(:venue) { create(:venue, :with_shows) }

    let(:expected_as_json) do
      {
        id: venue.id,
        name: venue.name,
        other_names: venue.other_names,
        latitude: venue.latitude.round(6),
        longitude: venue.longitude.round(6),
        shows_count: venue.shows_count,
        location: venue.location,
        slug: venue.slug,
        updated_at: venue.updated_at.iso8601
      }
    end
    let(:expected_as_json_api) do
      {
        id: venue.id,
        name: venue.name,
        other_names: venue.other_names,
        latitude: venue.latitude.round(6),
        longitude: venue.longitude.round(6),
        shows_count: venue.shows_count,
        location: venue.location,
        city: venue.city,
        state: venue.state,
        country: venue.country,
        slug: venue.slug,
        show_dates: venue.shows.order(date: :asc).map(&:date).map(&:iso8601),
        show_ids: venue.shows.order(date: :asc).map(&:id),
        updated_at: venue.updated_at.iso8601
      }
    end

    it 'provides #as_json' do
      expect(venue.as_json).to eq(expected_as_json)
    end

    it 'provides #as_json_api' do
      expect(venue.as_json_api).to eq(expected_as_json_api)
    end
  end
end
