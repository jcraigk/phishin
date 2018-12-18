# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::SongsController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }
  let(:json_data) { json[:data] }

  describe 'index' do
    subject { get('/api/v1/songs', {}, auth_header) }

    let!(:songs) { create_list(:song, 3, :with_tracks) }

    it 'responds with expected data' do
      expect(json_data).to match_array(songs.map(&:as_json))
    end
  end

  describe 'show' do
    let(:song) { create(:song) }

    context 'when requesting by id' do
      subject { get("/api/v1/songs/#{song.id}", {}, auth_header) }

      it 'responds with expected data' do
        expect(json_data).to eq(song.as_json_api)
      end
    end

    context 'when requesting by slug' do
      subject { get("/api/v1/songs/#{song.slug}", {}, auth_header) }

      it 'responds with expected data' do
        expect(json_data).to eq(song.as_json_api)
      end
    end

    context 'when requesting invalid song' do
      subject { get('/api/v1/songs/nonexistent-song', {}, auth_header) }

      include_examples 'responds with 404'
    end
  end
end
