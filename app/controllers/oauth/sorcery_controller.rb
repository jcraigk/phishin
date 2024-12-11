require "typhoeus"

class Oauth::SorceryController < ApplicationController
  def login
    login_at(params[:provider])
  end

  def callback
    provider = params[:provider]
    auth = build_auth_hash(provider)
    user = User.where(email: auth[:email]).first_or_initialize
    user.save! unless user.persisted?

    user.authentications.where(provider:).first_or_create! do |authentication|
      authentication.uid = auth[:uid]
    end

    reset_session
    store_user_data_in_session(user)
    redirect_to root_path
  rescue StandardError => e
    Sentry.capture_exception(e)
    redirect_to root_path, alert: "Login with Google failed"
  end

  private

  def store_user_data_in_session(user)
    session[:jwt] = jwt_for(user)
    session[:username] = user.username
    session[:username_updated_at] = user.username_updated_at
    session[:email] = user.email
  end

  def jwt_for(user)
    JWT.encode(
      {
        sub: user.id,
        exp: (Time.now + 1.year).to_i
      },
      Rails.application.secret_key_base,
      "HS256"
    )
  end

  def build_auth_hash(provider)
    response = Typhoeus.get \
      "https://www.googleapis.com/oauth2/v2/userinfo",
      headers: { Authorization: "Bearer #{fetch_access_token}" }
    data = JSON.parse(response.body)
    {
      uid: data["id"],
      email: data["email"]
    }
  end

  def fetch_access_token
    response = Typhoeus.post(
      "https://oauth2.googleapis.com/token",
      body: {
        code: params[:code],
        client_id: Rails.application.config.sorcery.google.key,
        client_secret: Rails.application.config.sorcery.google.secret,
        redirect_uri: Rails.application.config.sorcery.google.callback_url,
        grant_type: "authorization_code"
      }
    )
    JSON.parse(response.body)["access_token"]
  end
end
