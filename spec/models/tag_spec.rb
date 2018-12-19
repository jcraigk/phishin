# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Tag do
  subject { create(:tag, name: 'Musical Tease') }

  it { is_expected.to have_many(:show_tags) }
  it { is_expected.to have_many(:shows).through(:show_tags) }
  it { is_expected.to have_many(:track_tags) }
  it { is_expected.to have_many(:tracks).through(:track_tags) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:color) }
  it { is_expected.to validate_presence_of(:priority) }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_uniqueness_of(:priority) }

  it 'generates a slug from name (friendly_id)' do
    subject.save
    expect(subject.slug).to eq('musical-tease')
  end

  context 'serialization' do
    subject { create(:tag, :with_tracks, :with_shows) }

    it 'provides #as_json' do
      expect(subject.as_json).to eq(
        id: subject.id,
        name: subject.name,
        slug: subject.slug,
        description: subject.description,
        updated_at: subject.updated_at.iso8601
      )
    end

    it 'provides #as_json_api' do
      expect(subject.as_json_api).to eq(
        id: subject.id,
        name: subject.name,
        slug: subject.slug,
        description: subject.description,
        updated_at: subject.updated_at.iso8601,
        show_ids: subject.shows.sort_by(&:id).map(&:id),
        track_ids: subject.tracks.sort_by(&:id).map(&:id)
      )
    end
  end
end
