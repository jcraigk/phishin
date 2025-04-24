require 'rails_helper'

describe Api::V1::ToursController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    subject { get('/api/v1/tours', {}, auth_header) }

    let!(:tours) { create_list(:tour, 3, :with_shows) }

    it 'responds with expected data' do
      expect(json_data).to match_array(tours.map(&:as_json_api))
    end
  end

  describe 'show' do
    context 'with valid id param' do
      subject { get("/api/v1/tours/#{tour.id}", {}, auth_header) }

      let(:tour) { create(:tour) }

      it 'responds with expected data' do
        expect(json_data).to eq(tour.as_json_api)
      end
    end

    context 'with invalid id param' do
      subject { get('/api/v1/tours/nonexistent-tour', {}, auth_header) }

      it_behaves_like 'responds with 404'
    end
  end
end
