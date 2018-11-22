# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ShowsController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    let!(:shows) { create_list(:show, 3, :with_tracks, :with_tags, :with_likes) }
    subject { get('/api/v1/shows') }

    it 'responds with expected data' do
      expect(json_data).to match_array(shows.map(&:as_json_api))
    end
  end

  describe 'show' do
    context 'with valid id param' do
      let(:show) { create(:show) }
      subject { get("/api/v1/shows/#{show.id}") }

      it 'responds with expected data' do
        expect(json_data).to eq(show.as_json_api)
      end
    end

    context 'with invalid id param' do
      subject { get('/api/v1/shows/nonexistent-show') }

      include_examples 'responds with 404'
    end
  end

  # TODO: Random and other methods
end
