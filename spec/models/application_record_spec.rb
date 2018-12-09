# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ApplicationRecord do
  subject { described_class.new }

  let(:described_class) { User }

  it 'exists' do
    expect(subject.class).to eq(described_class)
  end
end
