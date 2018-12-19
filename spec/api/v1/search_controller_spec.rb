# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::SearchController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'show' do
    subject { get("/api/v1/search/#{term}", {}, auth_header) }

    let!(:term) { 'fall' }
    let!(:tour) { create(:tour, name: '1995 Fall Tour') }

    it 'responds with expected results' do
      expect(json_data).to eq(
        show: nil,
        other_shows: [],
        songs: [],
        venues: [],
        tours: [
          {
            id: tour.id,
            name: tour.name,
            shows_count: tour.shows_count,
            starts_on: tour.starts_on.to_s,
            ends_on: tour.ends_on.to_s,
            slug: tour.slug,
            updated_at: tour.updated_at.to_s
          }
        ]
      )
    end
  end
end
