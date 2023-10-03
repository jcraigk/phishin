require 'rails_helper'

RSpec.describe Tag do
  subject(:tag) { create(:tag, name: 'Musical Tease') }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to have_many(:show_tags).dependent(:destroy) }
  it { is_expected.to have_many(:shows).through(:show_tags) }
  it { is_expected.to have_many(:track_tags).dependent(:destroy) }
  it { is_expected.to have_many(:tracks).through(:track_tags) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:color) }
  it { is_expected.to validate_presence_of(:priority) }
  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_uniqueness_of(:priority) }

  it 'generates a slug from name (friendly_id)' do
    tag.save
    expect(tag.slug).to eq('musical-tease')
  end

  describe 'serialization' do
    subject(:tag) { create(:tag, :with_tracks, :with_shows) }

    let(:expected_as_json) do
      {
        id: tag.id,
        name: tag.name,
        slug: tag.slug,
        group: tag.group,
        color: tag.color,
        priority: tag.priority,
        description: tag.description,
        updated_at: tag.updated_at.iso8601
      }
    end
    let(:expected_as_json_api) do
      {
        id: tag.id,
        name: tag.name,
        slug: tag.slug,
        group: tag.group,
        color: tag.color,
        priority: tag.priority,
        description: tag.description,
        updated_at: tag.updated_at.iso8601,
        show_ids: tag.shows.sort_by(&:id).map(&:id),
        track_ids: tag.tracks.sort_by(&:id).map(&:id)
      }
    end

    it 'provides #as_json' do
      expect(tag.as_json).to eq(expected_as_json)
    end

    it 'provides #as_json_api' do
      expect(tag.as_json_api).to eq(expected_as_json_api)
    end
  end
end
