# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ErasController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].symbolize_keys }

  describe 'index' do
    subject { get('/api/v1/eras') }

    it 'returns the expected data' do
      expect(json).to eq(
        success: true,
        total_entries: 1,
        total_pages: 1,
        page: 1,
        data: ERAS
      )
    end
  end

  describe 'show' do
    let(:era) { '3.0' }
    subject { get("/api/v1/eras/#{era}") }

    it 'returns the expected data' do
      expect(json).to eq(
        success: true,
        total_entries: 1,
        total_pages: 1,
        page: 1,
        data: ERAS[era]
      )
    end
  end
end
