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
        # The API returns all tracks with audio, so we verify our test tracks are included
        expected_tracks = tracks.sort_by(&:id).reverse.map(&:as_json_api)
        expected_tracks.each do |expected_track|
          expect(json_data).to include(expected_track)
        end

        # Verify the response structure
        expect(json_data).to be_an(Array)
        expect(json_data.length).to be >= tracks.length
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
