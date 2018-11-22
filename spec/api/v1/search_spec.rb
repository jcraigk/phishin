# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::SearchController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  # TODO:
  # describe 'show' do
  #   let(:playlist) { create(:playlist, :with_tracks) }
  #   subject { get("/api/v1/playlists/#{playlist.slug}") }

  #   it 'responds with expected data' do
  #     expect(json_data).to eq(playlist.as_json_api)
  #   end
  # end
end
