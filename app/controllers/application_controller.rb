class ApplicationController < ActionController::Base
  include ReactOnRailsHelper
  include ActionView::Helpers::TagHelper

  def application
    # Set up initial props, including the context for SSR
    context = {}

    @props = {
      # SSR
      location: request.fullpath,
      context:, # Pass this context to React on Rails

      # OAuth login
      jwt: session[:jwt],
      username: session[:username],
      email: session[:email],
      alert: flash[:alert],
      notice: flash[:notice],
      mapbox_token: ENV.fetch("MAPBOX_TOKEN", nil)
    }

    # Clear session after OAuth redirect
    session.delete(:jwt)
    session.delete(:username)
    session.delete(:email)

    # react_app = react_component_hash("App", prerender: false, props: @props)
    # binding.irb

    # Render the view and layout
    render html: "", layout: "application"
    # render html: react_app, layout: "application"
  end
end
