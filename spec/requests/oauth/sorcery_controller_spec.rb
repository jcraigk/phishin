require "rails_helper"

RSpec.describe "Oauth::SorceryController" do
  describe "GET /oauth/:provider" do
    it "returns 404 for unknown provider" do
      get "/oauth/unknown"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /oauth/callback/:provider" do
    it "returns 404 for unknown provider" do
      get "/oauth/callback/unknown"
      expect(response).to have_http_status(:not_found)
    end
  end
end
