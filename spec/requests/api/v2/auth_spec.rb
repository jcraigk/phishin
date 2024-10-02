require "rails_helper"

RSpec.describe "API v2 Auth" do
  let!(:user) { create(:user, password: "password") }

  describe "POST /auth/create_user" do
    context "with valid parameters" do
      it "creates a new user, returns a JWT, and user information" do
        post_api "/auth/create_user", params: {
          username: "newuser",
          email: "new@example.com",
          password: "password",
          password_confirmation: "password"
        }
        expect(response).to have_http_status(:created)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:jwt]).to be_present
        expect(json[:username]).to eq("newuser")
        expect(json[:email]).to eq("new@example.com")
      end
    end

    context "when the email already exists" do
      before { create(:user, email: "existing@example.com") }

      it "returns a 409 error" do
        post_api "/auth/create_user", params: {
          username: "anotheruser",
          email: "existing@example.com",  # Duplicate email
          password: "password",
          password_confirmation: "password"
        }
        expect(response).to have_http_status(:conflict)

        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Email already exists")
      end
    end

    context "when passwords do not match" do
      it "returns a 422 error" do
        post_api "/auth/create_user", params: {
          username: "newuser",
          email: "new@example.com",
          password: "password",
          password_confirmation: "differentpassword"
        }
        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Passwords do not match")
      end
    end

    context "when missing required parameters" do
      it "returns a 422 error" do
        post_api "/auth/create_user", params: {
          username: "newuser",
          email: "",
          password: "password",
          password_confirmation: "password"
        }
        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json["message"]).to include("Email is invalid")
      end
    end
  end

  describe "POST /auth/login" do
    context "with valid credentials" do
      it "returns a JWT token and user information" do
        post_api "/auth/login", params: { email: user.email, password: "password" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:jwt]).to be_present
        expect(json[:username]).to eq(user.username)
        expect(json[:email]).to eq(user.email)
      end
    end

    context "with invalid credentials" do
      it "returns a 401 error" do
        post_api "/auth/login", params: { email: user.email, password: "wrongpassword" }
        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Invalid email or password")
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

  describe "POST /auth/request_password_reset" do
    context "when the email exists" do
      it "returns a 200 status and sends password reset instructions" do
        expect_any_instance_of(User).to receive(:deliver_reset_password_instructions!)
        post_api "/auth/request_password_reset", params: { email: user.email }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq \
          "Password reset instructions will be sent to the email if it exists"
      end
    end

    context "when the email does not exist" do
      it "returns a 200 status and sends no email" do
        post_api "/auth/request_password_reset", params: { email: "nonexistent@example.com" }
        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:message]).to eq \
          "Password reset instructions will be sent to the email if it exists"
      end
    end
  end

  describe "POST /auth/reset_password" do
    before do
      user.deliver_reset_password_instructions!
      @token = user.reset_password_token
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
        expect(json[:message]).to eq("Password reset successfully")
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
        expect(json["message"]).to eq("Invalid token")
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
        expect(json["message"]).to eq("Password reset failed")
      end
    end
  end

  describe "PATCH /auth/change_username/:username" do
    context "when the username can be changed" do
      it "updates the username and returns the user information" do
        patch_api_authed(user, "/auth/change_username/newusername")
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:username]).to eq("newusername")
        expect(user.reload.username_updated_at).to be_within(1.minute).of(Time.current)
      end
    end

    context "when the username cannot be changed (cooldown period)" do
      before { user.update(username_updated_at: 6.months.ago) }

      it "returns a 403 error" do
        patch_api_authed(user, "/auth/change_username/newusername")
        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json["message"]).to eq("Username can only be changed once per year")
      end
    end

    context "when the update fails" do
      it "returns a 422 error" do
        allow_any_instance_of(User).to receive(:update).and_return(false)
        patch_api_authed(user, "/auth/change_username/invalidusername")
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
