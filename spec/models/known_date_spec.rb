require 'rails_helper'

RSpec.describe KnownDate do
  subject { build(:known_date) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to validate_uniqueness_of(:date) }
  it { is_expected.to validate_presence_of(:phishnet_url) }
  it { is_expected.to validate_presence_of(:location) }
  it { is_expected.to validate_presence_of(:venue) }

  describe '#date_with_dots' do
    let(:known_date) { build(:known_date, date: Date.new(2023, 1, 1)) }

    it 'returns the date in dot-separated format' do
      expect(known_date.date_with_dots).to eq("2023.01.01")
    end
  end
end
