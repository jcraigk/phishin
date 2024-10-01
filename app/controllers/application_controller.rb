class ApplicationController < ActionController::Base
  def application
    @meta = MetaTagService.call(request.path)
    @props = {
      # OAuth login
      jwt: session[:jwt],
      username: session[:username],
      usernameUpdatedAt: session[:username_updated_at],
      email: session[:email],
      alert: flash[:alert],

      # Misc
      usernameCooldown: App.username_cooldown.to_i,

      # Third party integrations
      mapboxToken: ENV.fetch("MAPBOX_TOKEN", nil)
    }

    # Clear session after OAuth redirect
    session.delete(:jwt)
    session.delete(:username)
    session.delete(:username_updated_at)
    session.delete(:email)

    # Render layout + React app
    render html: "", layout: "application", status: @meta[:status]
  end
end
