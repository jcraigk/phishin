require "rails_helper"

RSpec.describe "API v2 Auth" do
  let!(:user) { create(:user, password: "password") }

  describe "POST /auth/login" do
    context "with valid credentials" do
      it "returns a JWT token and user information" do
        post_authorized "/auth/login", params: { email: user.email, password: "password" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:token]).to be_present
        expect(json[:username]).to eq(user.username)
        expect(json[:email]).to eq(user.email)
      end
    end

    context "with invalid credentials" do
      it "returns a 401 error" do
        post_authorized "/auth/login", params: { email: user.email, password: "wrongpassword" }
        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid email or password")
      end
    end
  end

  describe "GET /auth/user" do
    context "with a valid token" do
      it "returns the currently logged-in user" do
        token = JWT.encode(
          {
            sub: user.id,
            exp: (Time.now + 1.year).to_i
          },
          Rails.application.secret_key_base,
          "HS256"
        )

        get_authorized "/auth/user", headers: { "X-Auth-Token" => token }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:username]).to eq(user.username)
        expect(json[:email]).to eq(user.email)
      end
    end

    context "with an invalid token" do
      it "returns a 401 error" do
        get_authorized "/auth/user", headers: { "X-Auth-Token" => "invalid.token.here" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
