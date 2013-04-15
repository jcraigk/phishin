class ErrorsController < ApplicationController
  
  def browser_unsupported
    render layout: false
  end
  
  def mobile_unsupported
    render layout: false
  end
  
end