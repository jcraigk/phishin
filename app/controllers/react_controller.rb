class ReactController < ApplicationController
  layout "react"

  def index
    @props = {
      app_name: App.app_name,
      contact_email: App.contact_email,
    }
  end
end
