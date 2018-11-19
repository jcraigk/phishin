# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::TracksController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    subject { get('/api/v1/tracks') }
    let!(:tracks) { create_list(:track, 3, :with_likes) }

    it 'returns the expected data' do
      expect(json_data).to eq(tracks.map(&:as_json_api))
    end
  end

  describe 'show' do
    let(:track) { create(:track) }
    subject { get("/api/v1/tracks/#{track.id}") }

    it 'returns the expected data' do
      expect(json_data).to eq(track.as_json_api)
    end
  end
end
