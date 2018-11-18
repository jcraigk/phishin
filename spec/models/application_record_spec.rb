# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ApplicationRecord do
  let(:described_class) { User }
  subject { described_class.new }

  it 'exists' do
    expect(subject.class).to eq(described_class)
  end
end
