# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::TracksController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    let!(:tracks) { create_list(:track, 3, :with_likes) }
    subject { get('/api/v1/tracks') }

    it 'responds with expected data' do
      expect(json_data).to match_array(tracks.map(&:as_json_api))
    end
  end

  describe 'show' do
    let(:track) { create(:track) }
    subject { get("/api/v1/tracks/#{track.id}") }

    it 'responds with expected data' do
      expect(json_data).to eq(track.as_json_api)
    end
  end
end
