require 'rails_helper'

RSpec.describe VenueRename do
  subject { build(:venue_rename) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to belong_to(:venue) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:renamed_on) }

  describe 'touch behavior' do
    let(:venue) { create(:venue) }

    it 'touches the venue when created' do
      venue.update_column(:updated_at, 1.day.ago)
      create(:venue_rename, venue:)
      expect(venue.reload.updated_at).to be > 1.minute.ago
    end

    it 'touches the venue when destroyed' do
      venue_rename = create(:venue_rename, venue:)
      venue.update_column(:updated_at, 1.day.ago)
      venue_rename.destroy
      expect(venue.reload.updated_at).to be > 1.minute.ago
    end
  end
end
