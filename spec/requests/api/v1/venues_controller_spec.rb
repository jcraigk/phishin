require 'rails_helper'

describe Api::V1::VenuesController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }
  let(:json_data) { json[:data] }

  describe 'index' do
    subject { get('/api/v1/venues', {}, auth_header) }

    let!(:venues) { create_list(:venue, 3, :with_shows) }

    it 'responds with expected data' do
      expect(json_data).to match_array(venues.map(&:as_json_api))
    end
  end

  describe 'show' do
    let(:venue) { create(:venue) }

    context 'when requesting by id' do
      subject { get("/api/v1/venues/#{venue.id}", {}, auth_header) }

      it 'responds with expected data' do
        expect(json_data).to eq(venue.as_json_api)
      end
    end

    context 'when requesting by slug' do
      subject { get("/api/v1/venues/#{venue.slug}", {}, auth_header) }

      it 'responds with expected data' do
        expect(json_data).to eq(venue.as_json_api)
      end
    end

    context 'when requesting invalid venue' do
      subject { get('/api/v1/venues/nonexistent-venue', {}, auth_header) }

      it_behaves_like 'responds with 404'
    end
  end
end
