require 'rails_helper'

describe Api::V1::ErasController do
  include Rack::Test::Methods

  let(:json_data) { JSON[subject.body].symbolize_keys[:data] }

  describe 'index' do
    subject { get('/api/v1/eras', {}, auth_header) }

    it 'responds with expected data' do
      expect(json_data).to eq(ERAS)
    end
  end

  describe 'show' do
    context 'with valid id param' do
      subject { get("/api/v1/eras/#{era}", {}, auth_header) }

      let(:era) { '3.0' }

      it 'responds with expected data' do
        expect(json_data).to eq(ERAS[era])
      end
    end

    context 'with invalid id param' do
      subject { get('/api/v1/eras/nonexistent-era', {}, auth_header) }

      it_behaves_like 'responds with 404'
    end
  end
end
