# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ToursController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }

  describe 'index' do
    subject { get('/api/v1/tours') }
    let!(:tours) { create_list(:tour, 3, :with_shows) }

    it 'returns the expected data' do
      expect(json).to eq(
        success: true,
        total_entries: 3,
        total_pages: 1,
        page: 1,
        data: tours.map(&:as_json_api)
      )
    end
  end

  describe 'show' do
    let(:tour) { create(:tour) }
    subject { get("/api/v1/tours/#{tour.id}") }

    it 'returns the expected data' do
      expect(json).to eq(
        success: true,
        total_entries: 1,
        total_pages: 1,
        page: 1,
        data: tour.as_json_api
      )
    end
  end
end
