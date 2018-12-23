# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::SearchController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }

  describe 'show' do
    subject { get "/api/v1/search/#{term}" }

    context 'with invalid term' do
      let(:term) { 'a' }

      it 'responds with error and 400' do
        expect(subject.status).to eq(400)
        expect(json).to eq(
          success: false,
          message: 'Search term must be at least 3 characters long'
        )
      end
    end

    context 'with valid term' do
      let(:term) { 'fall' }
      let!(:tour) { create(:tour, name: '1995 Fall Tour') }

      it 'responds with expected results' do
        expect(subject.status).to eq(200)
        expect(json[:data]).to eq(
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
          track_tags: []
        )
      end
    end
  end
end
