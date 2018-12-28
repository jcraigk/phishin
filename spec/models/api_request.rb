# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ApiRequest, type: :model do
  subject { build(:api_request) }

  it { is_expected.to be_an(ApplicationRecord) }
  it { is_expected.to belong_to(:api_key) }

  describe 'attributes' do
    subject { described_class.attribute_names.map(&:to_sym) }
    it { is_expected.to include :id }
    it { is_expected.to include :api_key }
    it { is_expected.to include :path }
    it { is_expected.to include :created_at }
    it { is_expected.to include :updated_at }
  end
end
