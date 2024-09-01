class ReactController < ApplicationController
  layout "react"

  def index
    @props = {
      app_name: App.app_name,
      base_url: App.base_url,
      contact_email: App.contact_email
    }
  end
end
