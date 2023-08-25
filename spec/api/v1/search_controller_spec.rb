# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::SearchController do
  include Rack::Test::Methods

  let(:json) { JSON[response.body].deep_symbolize_keys }

  describe 'show' do
    subject(:response) { get("/api/v1/search/#{term}", {}, auth_header) }

    context 'with invalid term' do
      let(:term) { 'a' }

      it 'returns 400' do
        expect(response.status).to eq(400)
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
      let!(:tour) { create(:tour, name: '1995 Fall Tour') }
      let(:expected_json) do
        {
          exact_show: nil,
          other_shows: [],
          songs: [],
          venues: [],
          tours: [
            {
              id: tour.id,
              name: tour.name,
              shows_count: tour.shows_count,
              starts_on: tour.starts_on.iso8601,
              ends_on: tour.ends_on.iso8601,
              slug: tour.slug,
              updated_at: tour.updated_at.iso8601
            }
          ],
          tags: [],
          show_tags: [],
          track_tags: [],
          tracks: []
        }
      end

      it 'returns 200' do
        expect(response.status).to eq(200)
      end

      it 'returns expected data' do
        expect(json[:data]).to eq(expected_json)
      end
    end
  end
end
