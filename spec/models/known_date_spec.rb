# frozen_string_literal: true
require 'rails_helper'

RSpec.describe KnownDate do
  subject { build(:known_date) }

  it { is_expected.to be_an(ApplicationRecord) }

  it { is_expected.to validate_uniqueness_of(:date) }
  it { is_expected.to validate_presence_of(:phishnet_url) }
  it { is_expected.to validate_presence_of(:location) }
  it { is_expected.to validate_presence_of(:venue) }

  describe 'attributes' do
    subject(:attrs) { described_class.attribute_names.map(&:to_sym) }

    it { is_expected.to include :date }
    it { is_expected.to include :phishnet_url }
    it { is_expected.to include :location }
    it { is_expected.to include :venue }
  end
end
