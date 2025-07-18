require "rails_helper"

describe Api::V1::ApiController do
  include Rack::Test::Methods

  subject(:response) { get(path, params, headers) }

  let(:headers) { auth_header }
  let(:json) { JSON[response.body].deep_symbolize_keys }
  let(:params) { {} }
  let(:path) { "/api/v1/tags" }

  context "with no authorization header" do
    let(:headers) { {} }

    it "returns a 401" do
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "paging" do
    let!(:tags) { create_list(:tag, 25).sort_by(&:name) }
    let(:expected_json) do
      {
        success: true,
        total_entries: 25,
        total_pages: 2,
        page: 1,
        data: tags.first(20).map(&:as_json)
      }
    end

    context "with only sort params" do
      let(:params) { { sort_attr: :name, sort_dir: :asc } }

      it "responds with expected data" do
        expect(json).to eq(expected_json)
      end
    end

    context "with page param" do
      let(:params) { { page: 2, sort_attr: :name, sort_dir: :asc } }
      let(:expected_json) do
        {
          success: true,
          total_entries: 25,
          total_pages: 2,
          page: 2,
          data: tags[20..39].map(&:as_json)
        }
      end

      it "responds with expected data" do
        expect(json).to eq(expected_json)
      end
    end
  end
end
