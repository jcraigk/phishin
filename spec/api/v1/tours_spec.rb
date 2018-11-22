# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ToursController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    let!(:tours) { create_list(:tour, 3, :with_shows) }
    subject { get('/api/v1/tours') }

    it 'responds with expected data' do
      expect(json_data).to match_array(tours.map(&:as_json_api))
    end
  end

  describe 'show' do
    context 'with valid id param' do
      let(:tour) { create(:tour) }
      subject { get("/api/v1/tours/#{tour.id}") }

      it 'responds with expected data' do
        expect(json_data).to eq(tour.as_json_api)
      end
    end

    context 'with invalid id param' do
      subject { get('/api/v1/tours/nonexistent-tour') }

      include_examples 'responds with 404'
    end
  end
end
