# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tour do
  subject(:tour) { create(:tour, name: '1996 Summer Tour') }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:shows) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_presence_of(:starts_on) }
  it { is_expected.to validate_uniqueness_of(:starts_on) }
  it { is_expected.to validate_presence_of(:ends_on) }
  it { is_expected.to validate_uniqueness_of(:ends_on) }

  it 'generates a slug from name (friendly_id)' do
    tour.save
    expect(tour.slug).to eq('1996-summer-tour')
  end

  describe 'serialization' do
    subject(:tour) { create(:tour, :with_shows) }

    let(:expected_as_json) do
      {
        id: tour.id,
        name: tour.name,
        shows_count: tour.shows_count,
        starts_on: tour.starts_on.iso8601,
        ends_on: tour.ends_on.iso8601,
        slug: tour.slug,
        updated_at: tour.updated_at.iso8601
      }
    end
    let(:expected_as_json_api) do
      {
        id: tour.id,
        name: tour.name,
        shows_count: tour.shows_count,
        slug: tour.slug,
        starts_on: tour.starts_on.iso8601,
        ends_on: tour.ends_on.iso8601,
        shows: tour.shows.sort_by(&:date).as_json,
        updated_at: tour.updated_at.iso8601
      }
    end

    it 'provides #as_json' do
      expect(tour.as_json).to eq(expected_as_json)
    end

    it 'provides #as_json_api' do
      expect(tour.as_json_api).to eq(expected_as_json_api)
    end
  end
end
