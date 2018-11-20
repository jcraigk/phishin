# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::SongsController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }
  let(:json_data) { json[:data] }

  describe 'index' do
    let!(:songs) { create_list(:song, 3, :with_tracks) }
    subject { get('/api/v1/songs') }

    it 'responds with expected data' do
      expect(json_data).to match_array(songs.map(&:as_json))
    end
  end

  describe 'show' do
    let(:song) { create(:song) }

    context 'when requesting by id' do
      subject { get("/api/v1/songs/#{song.id}") }

      it 'responds with expected data' do
        expect(json_data).to eq(song.as_json_api)
      end
    end

    context 'when requesting by slug' do
      subject { get("/api/v1/songs/#{song.slug}") }

      it 'responds with expected data' do
        expect(json_data).to eq(song.as_json_api)
      end
    end

    context 'when requesting invalid song' do
      subject { get("/api/v1/songs/nonexistent-song") }

      it 'responds with error' do
        expect(subject.status).to eq(404)
        expect(json).to eq(
          success: false,
          message: 'Record not found'
        )
      end
    end
  end
end
