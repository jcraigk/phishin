require 'rails_helper'

describe Api::V1::SearchController do
  include Rack::Test::Methods

  let(:json) { JSON[response.body].deep_symbolize_keys }

  describe 'show' do
    subject(:response) { get("/api/v1/search/#{term}", {}, auth_header) }

    context 'with invalid term' do
      let(:term) { 'a' }

      it 'returns 400' do
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns expected data' do
        expect(json).to eq(
          success: false,
          message: 'Search term must be at least 3 characters long'
        )
      end
    end

    context 'with valid term' do
      let(:term) { 'fall' }
      let(:tour) { create(:tour, name: '1995 Fall Tour') }
      let(:expected_json) do
        {
          exact_show: nil,
          other_shows: [],
          songs: [],
          venues: [],
          tags: [],
          show_tags: [],
          track_tags: [],
          tracks: [],
          playlists: []
        }
      end

      before { tour }

      it 'returns 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns expected data' do
        expect(json[:data]).to eq(expected_json)
      end
    end
  end
end
