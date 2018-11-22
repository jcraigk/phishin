# frozen_string_literal: true
require 'rails_helper'

describe Api::V1::ApiController do
  include Rack::Test::Methods

  let(:json) { JSON[subject.body].deep_symbolize_keys }
  let(:path) { '/api/v1/tags' }

  describe 'paging' do
    let!(:tags) { create_list(:tag, 50) }
    subject { get(path) }

    context 'without params' do
      it 'responds with expected data' do
        expect(json).to eq(
          success: true,
          total_entries: 50,
          total_pages: 3,
          page: 1,
          data: tags.first(20).map(&:as_json)
        )
      end
    end

    context 'with page param' do
      subject { get("#{path}?page=2") }

      it 'responds with expected data' do
        expect(json).to eq(
          success: true,
          total_entries: 50,
          total_pages: 3,
          page: 2,
          data: tags[20..39].map(&:as_json)
        )
      end
    end
  end
end
