require 'rails_helper'

describe Api::V1::PlaylistsController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'show' do
    context 'with valid id param' do
      subject { get("/api/v1/playlists/#{playlist.slug}", {}, auth_header) }

      let(:playlist) { create(:playlist) }

      it 'responds with expected data' do
        expect(json_data).to eq(playlist.as_json_api)
      end
    end

    context 'with invalid id param' do
      subject { get('/api/v1/playlists/nonexistent-playlist', {}, auth_header) }

      it_behaves_like 'responds with 404'
    end
  end
end
