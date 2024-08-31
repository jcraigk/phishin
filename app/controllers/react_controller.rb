class ReactController < ApplicationController
  layout "react"

  def index
    @props = { app_name: App.app_name }
  end
end
