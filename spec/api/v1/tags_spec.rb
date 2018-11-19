# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::TagsController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    subject { get('/api/v1/tags') }
    let!(:tags) { create_list(:tag, 3) }

    it 'returns the expected data' do
      expect(json_data).to match_array(tags.map(&:as_json))
    end
  end

  describe 'show' do
    let(:tag) { create(:tag, :with_tracks, :with_shows) }
    subject { get("/api/v1/tags/#{tag.id}") }

    it 'returns the expected data' do
      expect(json_data).to eq([tag.as_json_api])
    end
  end
end
