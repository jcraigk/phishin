require 'rails_helper'

describe Api::V1::ShowsController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].deep_symbolize_keys[:data] }

  describe 'index' do
    let!(:shows) { create_list(:show, 3, :with_tracks, :with_tags, :with_likes) }

    context 'without params' do
      subject { get('/api/v1/shows', {}, auth_header) }

      it 'responds with expected data' do
        expect(json_data).to match_array(shows.map(&:as_json_api))
      end
    end

    context 'when providing tag param' do
      subject { get("/api/v1/shows?tag=#{tag.slug}", {}, auth_header) }

      let(:tag) { create(:tag) }

      before { shows.first.tags = [ tag ] }

      it 'responds with expected data' do
        expect(json_data).to eq([ shows.first.reload.as_json_api ])
      end
    end
  end

  describe 'show' do
    context 'with valid id param' do
      subject { get("/api/v1/shows/#{show.id}", {}, auth_header) }

      let(:show) { create(:show) }

      before do
        create(:show_tag, show:, tag: create(:tag, name: 'SBD'))
      end

      it 'responds with expected data' do
        expect(json_data).to eq(show.as_json_api)
        expect(json_data[:remastered]).to be(false)
        expect(json_data[:sbd]).to be(true)
      end
    end

    context 'with valid date param' do
      subject { get("/api/v1/shows/#{show.date}", {}, auth_header) }

      let(:show) { create(:show) }

      it 'responds with expected data' do
        expect(json_data).to eq(show.as_json_api)
      end
    end

    context 'with invalid id param' do
      subject { get('/api/v1/shows/nonexistent-show', {}, auth_header) }

      it_behaves_like 'responds with 404'
    end
  end

  describe 'show-on-date/:date' do
    context 'with valid date param' do
      subject { get("/api/v1/show-on-date/#{show.date}", {}, auth_header) }

      let(:show) { create(:show) }

      it 'responds with expected data' do
        expect(json_data).to eq(show.as_json_api)
      end
    end

    context 'with invalid date param' do
      subject { get("/api/v1/show-on-date/#{show.date - 1.day}", {}, auth_header) }

      let(:show) { create(:show) }

      it_behaves_like 'responds with 404'
    end

    context 'with invalid param' do
      subject { get('/api/v1/show-on-date/invalid-date', {}, auth_header) }

      it_behaves_like 'responds with 404'
    end
  end

  describe 'shows-on-day-of-year/:day' do
    let!(:show) { create(:show, date: '1995-10-31') }

    context 'with valid long form date' do
      subject { get('/api/v1/shows-on-day-of-year/october-31', {}, auth_header) }

      it 'responds with expected data' do
        expect(json_data).to eq([ show.as_json_api ])
      end
    end

    context 'with valid short form date' do
      subject { get('/api/v1/shows-on-day-of-year/10-31', {}, auth_header) }

      it 'responds with expected data' do
        expect(json_data).to eq([ show.as_json_api ])
      end
    end

    context 'with invalid param' do
      subject { get('/api/v1/shows-on-day-of-year/invalid-day', {}, auth_header) }

      it_behaves_like 'responds with 404'
    end
  end
end
