# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ShowsController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    subject { get('/api/v1/shows') }
    let!(:shows) do
      create_list(
        :show,
        3,
        :with_tracks,
        :with_tags,
        :with_likes,
        missing: false
      )
    end

    it 'returns the expected data' do
      expect(json_data).to match_array(shows.map(&:as_json_api))
    end
  end

  describe 'show' do
    let(:show) { create(:show) }
    subject { get("/api/v1/shows/#{show.id}") }

    it 'returns the expected data' do
      expect(json_data).to eq(show.as_json_api)
    end
  end
end
