class Oauth::SorceryController < ApplicationController
  def login
    login_at(params[:provider])
  end

  def callback
    user = login_from(params[:provider], true) || create_from(params[:provider])
    store_user_data_in_session(user)
    redirect_to root_path
  rescue ActiveRecord::RecordNotUnique
    redirect_to root_path, alert: t("auth.email_taken", provider: provider_title)
  rescue StandardError => e
    Sentry.capture_exception(e)
    redirect_to root_path, alert: t("auth.external_fail", provider: provider_title)
  end

  private

  def store_user_data_in_session(user)
    session[:jwt] = jwt_for(user)
    session[:username] = user.username
    session[:email] = user.email
  end

  def provider_title
    params[:provider].titleize
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
end
