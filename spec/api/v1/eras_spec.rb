# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ErasController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].symbolize_keys[:data] }

  describe 'index' do
    subject { get('/api/v1/eras') }

    it 'returns the expected data' do
      expect(json_data).to eq(ERAS)
    end
  end

  describe 'show' do
    let(:era) { '3.0' }
    subject { get("/api/v1/eras/#{era}") }

    it 'returns the expected data' do
      expect(json_data).to eq(ERAS[era])
    end
  end
end
