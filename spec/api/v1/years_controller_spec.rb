# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::YearsController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }
  let(:json_data) { json[:data] }

  describe 'index' do
    before do
      create(:show, date: '1986-01-01')
      create(:show, date: '1987-01-01')
      create(:show, date: '1988-06-01')
    end

    context 'without params' do
      subject { get('/api/v1/years', {}, auth_header) }

      let(:expected_data) { ERAS.values.flatten }

      it 'responds with expected data' do
        expect(json_data).to match_array(expected_data)
      end
    end

    context 'with include_show_counts params' do
      subject { get('/api/v1/years?include_show_counts=true', {}, auth_header) }

      let(:expected_data) do
        data =
          ERAS.values
              .flatten
              .map { |e| { date: e, show_count: 0 } }
        data[0] = { date: '1983-1987', show_count: 2 }
        data[1] = { date: '1988', show_count: 1 }
        data
      end

      it 'responds with expected data' do
        expect(json_data).to match_array(expected_data)
      end
    end
  end

  describe 'show' do
    let(:year1) { 1999 }
    let(:year2) { 2000 }
    let(:tour) { create(:tour, starts_on: '1990-01-01', ends_on: '2000-12-31') }
    let!(:show1) { create(:show, date: "#{year1}-01-01", tour: tour) }
    let!(:show2) { create(:show, date: "#{year1}-02-01", tour: tour) }
    let!(:show3) { create(:show, date: "#{year2}-01-01", tour: tour) }

    before do
      create(:show, date: '1995-01-01', tour: tour) # Extra show
    end

    context 'when providing a single year' do
      subject { get("/api/v1/years/#{year1}", {}, auth_header) }

      let(:expected_shows) { [show1, show2].map(&:as_json_api) }

      it 'responds with expected data' do
        expect(json_data).to eq(expected_shows)
      end
    end

    context 'when providing a year range' do
      subject { get("/api/v1/years/#{year1}-#{year2}", {}, auth_header) }

      let(:expected_shows) { [show1, show2, show3].map(&:as_json_api) }

      it 'responds with expected data' do
        expect(json_data).to match_array(expected_shows)
      end
    end

    context 'when providing invalid input' do
      subject { get('/api/v1/years/bobweaver', {}, auth_header) }

      include_examples 'responds with 404'
    end
  end
end
