class ErrorsController < ApplicationController
  def browser_unsupported
    render layout: false
  end
end
