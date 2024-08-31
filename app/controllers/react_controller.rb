class ReactController < ApplicationController
  layout "hello_world"

  def index
    @props = { welcome: "Welcome" }
  end
end
