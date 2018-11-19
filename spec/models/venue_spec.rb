# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Venue do
  subject { build(:venue, name: 'Madison Square Garden') }

  it { is_expected.to have_many(:shows) }

  it 'generates a slug from name (friendly_id)' do
    subject.save
    expect(subject.slug).to eq('madison-square-garden')
  end

  # TODO: test `geocoded_by :address`

  context 'scopes' do
    context '#relevant' do
      let!(:venues_with_shows) { create_list(:venue, 2, :with_shows) }
      let!(:irrelevant_venue) { create(:venue) }

      it 'returns expected objects' do
        expect(described_class.relevant).to match_array(venues_with_shows)
      end
    end

    context '#name_starting_with' do
      let!(:a_venue) { create(:venue, name: 'Allstate Arena') }
      let!(:b_venue) { create(:venue, name: 'BlueCross Arena') }
      let!(:num_venue) { create(:venue, name: '13x13 Club') }

      it 'returns expected objects' do
        expect(described_class.name_starting_with('a')).to eq([a_venue])
        expect(described_class.name_starting_with('#')).to eq([num_venue])
      end
    end
  end

  context '#long_name' do
    subject do
      build(
        :venue,
        name: 'Madison Square Garden',
        abbrev: 'MSG',
        past_names: 'The Dump'
      )
    end

    it 'returns long name' do
      expect(subject.long_name).to eq('Madison Square Garden (MSG) (aka The Dump)')
    end
  end

  context '#location' do
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

  context 'serialization' do
    subject { create(:venue, :with_shows) }

    it 'provides #as_json' do
      expect(subject.as_json).to eq(
        id: subject.id,
        name: subject.name,
        past_names: subject.past_names,
        latitude: subject.latitude.round(6),
        longitude: subject.longitude.round(6),
        shows_count: subject.shows_count,
        location: subject.location,
        slug: subject.slug,
        updated_at: subject.updated_at.to_s
      )
    end

    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        id: subject.id,
        name: subject.name,
        past_names: subject.past_names,
        latitude: subject.latitude.round(6),
        longitude: subject.longitude.round(6),
        shows_count: subject.shows_count,
        location: subject.location,
        city: subject.city,
        state: subject.state,
        country: subject.country,
        slug: subject.slug,
        show_dates: subject.shows.order(date: :asc).map(&:date),
        show_ids: subject.shows.order(date: :asc).map(&:id),
        updated_at: subject.updated_at.to_s
      )
    end
  end
end
