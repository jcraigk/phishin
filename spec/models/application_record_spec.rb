require 'rails_helper'

RSpec.describe ApplicationRecord do
  subject(:record) { described_class.new }

  let(:described_class) { User }

  it 'exists' do
    expect(record.class).to eq(described_class)
  end
end
