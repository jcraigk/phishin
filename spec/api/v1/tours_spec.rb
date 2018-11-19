# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ToursController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    subject { get('/api/v1/tours') }
    let!(:tours) { create_list(:tour, 3, :with_shows) }

    it 'returns the expected data' do
      expect(json_data).to match_array(tours.map(&:as_json_api))
    end
  end

  describe 'show' do
    let(:tour) { create(:tour) }
    subject { get("/api/v1/tours/#{tour.id}") }

    it 'returns the expected data' do
      expect(json_data).to eq(tour.as_json_api)
    end
  end
end
