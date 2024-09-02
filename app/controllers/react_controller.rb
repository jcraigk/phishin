class ReactController < ApplicationController
  layout "react"

  def index
    @props = {
      app_name: App.app_name,
      base_url: App.base_url,
      contact_email: App.contact_email,
      oauth_providers: App.oauth_providers,
      jwt: session[:jwt],
      username: session[:username],
      email: session[:email],
      alert: flash[:alert],
      notice: flash[:notice]
    }

    session.delete(:jwt)
    session.delete(:username)
    session.delete(:email)
  end
end
