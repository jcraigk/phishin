# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::YearsController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }
  let(:json_data) { json[:data] }

  describe 'index' do
    let!(:show1) { create(:show, date: '1986-01-01') }
    let!(:show2) { create(:show, date: '1987-01-01') }
    let!(:show3) { create(:show, date: '1988-06-01') }

    context 'without params' do
      let(:expected_data) { ERAS.values.flatten }
      subject { get('/api/v1/years') }

      it 'responds with expected data' do
        expect(json_data).to match_array(expected_data)
      end
    end

    context 'with include_show_counts params' do
      let(:expected_data) do
        data =
          ERAS.values
              .flatten
              .map { |e| { date: e, show_count: 0 } }
        data[0] = { date: '1983-1987', show_count: 2 }
        data[1] = { date: '1988', show_count: 1 }
        data
      end
      subject { get('/api/v1/years?include_show_counts=true') }

      it 'responds with expected data' do
        expect(json_data).to match_array(expected_data)
      end
    end
  end

  describe 'show' do
    let(:year1) { 1999 }
    let(:year2) { 2000 }
    let!(:show1) { create(:show, date: "#{year1}-01-01") }
    let!(:show2) { create(:show, date: "#{year1}-02-01") }
    let!(:show3) { create(:show, date: "#{year2}-01-01") }
    let!(:show4) { create(:show, date: '1995-01-01') }

    context 'when providing a single year' do
      let(:expected_shows) { [show1, show2].map(&:as_json_api) }
      subject { get("/api/v1/years/#{year1}") }

      it 'responds with expected data' do
        expect(json_data).to eq(expected_shows)
      end
    end

    context 'when providing a year range' do
      let(:expected_shows) { [show1, show2, show3].map(&:as_json_api) }
      subject { get("/api/v1/years/#{year1}-#{year2}") }

      it 'responds with expected data' do
        expect(json_data).to match_array(expected_shows)
      end
    end

    # TODO: write api error matcher
    context 'when providing invalid input' do
      subject { get('/api/v1/years/bobweaver') }

      it 'returns error' do
        expect(subject.status).to eq(400)
        expect(json).to eq(
          success: false,
          message: 'Invalid year or year range'
        )
      end
    end
  end
end
