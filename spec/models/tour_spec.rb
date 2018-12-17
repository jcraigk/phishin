# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tour do
  subject { create(:tour, name: '1996 Summer Tour') }

  it { is_expected.to have_many(:shows) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_presence_of(:starts_on) }
  it { is_expected.to validate_uniqueness_of(:starts_on) }
  it { is_expected.to validate_presence_of(:ends_on) }
  it { is_expected.to validate_uniqueness_of(:ends_on) }

  it 'generates a slug from name (friendly_id)' do
    subject.save
    expect(subject.slug).to eq('1996-summer-tour')
  end

  context 'serialization' do
    subject { create(:tour, :with_shows) }

    it 'provides #as_json' do
      expect(subject.as_json).to eq(
        id: subject.id,
        name: subject.name,
        shows_count: subject.shows_count,
        starts_on: subject.starts_on.to_s,
        ends_on: subject.ends_on.to_s,
        slug: subject.slug,
        updated_at: subject.updated_at.to_s
      )
    end

    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        id: subject.id,
        name: subject.name,
        shows_count: subject.shows_count,
        slug: subject.slug,
        starts_on: subject.starts_on.to_s,
        ends_on: subject.ends_on.to_s,
        shows: subject.shows.sort_by(&:date).as_json,
        updated_at: subject.updated_at.to_s
      )
    end
  end
end
