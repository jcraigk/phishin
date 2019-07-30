# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ApiController do
  include Rack::Test::Methods

  subject(:response) { get(path, params, headers) }

  let(:headers) { auth_header }
  let(:json) { JSON[response.body].deep_symbolize_keys }
  let(:params) { {} }
  let(:path) { '/api/v1/tags' }

  context 'with no authorization header' do
    let(:headers) { {} }

    it 'returns a 401' do
      expect(response.status).to eq(401)
    end
  end

  describe 'api request logging' do
    before { allow(ApiRequest).to receive(:create) }

    it 'returns 200' do
      expect(response.status).to eq(200)
    end

    it 'creates an ApiRequest' do
      response
      expect(ApiRequest).to have_received(:create)
    end
  end

  describe 'paging' do
    let!(:tags) { create_list(:tag, 25) }
    let(:expected_json) do
      {
        success: true,
        total_entries: 25,
        total_pages: 2,
        page: 1,
        data: tags.first(20).map(&:as_json)
      }
    end

    context 'without params' do
      it 'responds with expected data' do
        expect(json).to eq(expected_json)
      end
    end

    context 'with page param' do
      let(:params) { { page: 2 } }
      let(:expected_json) do
        {
          success: true,
          total_entries: 25,
          total_pages: 2,
          page: 2,
          data: tags[20..39].map(&:as_json)
        }
      end

      it 'responds with expected data' do
        expect(json).to eq(expected_json)
      end
    end
  end
end
