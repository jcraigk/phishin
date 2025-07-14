require 'rails_helper'

describe Api::V1::TracksController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }
  let(:json_data) { json[:data] }

  describe 'index' do
    let!(:tracks) { create_list(:track, 3, :with_likes) }

    before do
      tracks.each { |t| t.tags = create_list(:tag, 3) }
    end

    context 'without params' do
      subject { get('/api/v1/tracks', {}, auth_header) }

      it 'responds with expected data' do
        # v1 API only returns tracks from shows that don't have missing audio
        expected_tracks = tracks.select { |t| t.show.audio_status != 'missing' }

        expected_json = expected_tracks.map(&:as_json_api)
        actual_json = json_data

        # Remove updated_at from comparison to avoid timing issues
        expected_json.each { |track| track.delete(:updated_at) }
        actual_json.each { |track| track.delete(:updated_at) }

        expect(actual_json).to match_array(expected_json)
      end
    end

    context 'when providing tag param' do
      subject { get("/api/v1/tracks?tag=#{tag.slug}", {}, auth_header) }

      let(:tag) { create(:tag) }

      before { tracks.first.tags << tag }

      it 'responds with expected data' do
        expect(json_data).to eq([ tracks.first.reload.as_json_api ])
      end
    end
  end

  describe 'show' do
    let(:track) { create(:track) }

    context 'with valid id param' do
      subject { get("/api/v1/tracks/#{track.id}", {}, auth_header) }

      it 'responds with expected data' do
        expect(json_data).to eq(track.as_json_api)
      end
    end

    context 'with invalid id param' do
      subject { get('/api/v1/tracks/nonexistent-track', {}, auth_header) }

      it_behaves_like 'responds with 404'
    end
  end
end
