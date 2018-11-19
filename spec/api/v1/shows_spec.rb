# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ShowsController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }

  describe 'index' do
    subject { get('/api/v1/shows') }
    let!(:shows) do
      create_list(
        :show,
        30,
        :with_tracks,
        :with_tags,
        :with_likes,
        missing: false
      )
    end

    it 'returns the expected data' do
      expect(json).to eq(
        success: true,
        total_entries: 30,
        total_pages: 2,
        page: 1,
        data: shows.first(20).map(&:as_json_api)
      )
    end
  end

  describe 'show' do
    let(:show) { create(:show) }
    subject { get("/api/v1/shows/#{show.id}") }

    it 'returns the expected data' do
      expect(json).to eq(
        success: true,
        total_entries: 1,
        total_pages: 1,
        page: 1,
        data: show.as_json_api
      )
    end
  end
end
