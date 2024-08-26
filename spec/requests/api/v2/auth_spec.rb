require "rails_helper"

RSpec.describe "API v2 Auth" do
  let!(:user) { create(:user, password: "password") }

  describe "POST /auth/login" do
    context "with valid credentials" do
      it "returns a JWT token and user information" do
        post_api "/auth/login", params: { email: user.email, password: "password" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:token]).to be_present
        expect(json[:username]).to eq(user.username)
        expect(json[:email]).to eq(user.email)
      end
    end

    context "with invalid credentials" do
      it "returns a 401 error" do
        post_api "/auth/login", params: { email: user.email, password: "wrongpassword" }
        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid email or password")
      end
    end
  end

  describe "GET /auth/user" do
    context "with a valid token" do
      it "returns the currently logged-in user" do
        get_api "/auth/user", headers: user_auth_header(user)
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:username]).to eq(user.username)
        expect(json[:email]).to eq(user.email)
      end
    end

    context "with an invalid token" do
      it "returns a 401 error" do
        get_api "/auth/user", headers: { "X-Auth-Token" => "invalid.token.here" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /auth/send_password_reset_email" do
    context "when the email exists" do
      it "returns a 200 status and sends password reset instructions" do
        expect_any_instance_of(User).to receive(:deliver_reset_password_instructions!)
        post_api "/auth/send_password_reset_email", params: { email: user.email }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq("If the email exists, reset instructions have been sent.")
      end
    end

    context "when the email does not exist" do
      it "returns a 200 status and sends no email" do
        post_api "/auth/send_password_reset_email", params: { email: "nonexistent@example.com" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq("If the email exists, reset instructions have been sent.")
      end
    end
  end

  describe "POST /auth/reset_password" do
    before do
      user.deliver_reset_password_instructions! # Send the reset instructions which sets the reset token
      @token = user.reset_password_token # Get the reset token from the user object
    end

    context "with valid token and matching passwords" do
      it "resets the user's password" do
        post_api "/auth/reset_password", params: {
          token: @token,
          password: "newpassword",
          password_confirmation: "newpassword"
        }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq("Password has been reset successfully.")
      end
    end

    context "with invalid token" do
      it "returns a 401 error" do
        post_api "/auth/reset_password", params: {
          token: "invalidtoken",
          password: "newpassword",
          password_confirmation: "newpassword"
        }
        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Invalid token")
      end
    end

    context "with non-matching passwords" do
      it "returns a 422 error" do
        post_api "/auth/reset_password", params: {
          token: @token,
          password: "newpassword",
          password_confirmation: "differentpassword"
        }
        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Password reset failed")
      end
    end
  end
end
