class PagesController < ApplicationController
  
  def legal_stuff
    render layout: false if request.xhr?
  end

  def contact_us
    render layout: false if request.xhr?
  end
  
  def browser_unsupported
    render layout: false
  end
  
  def mobile_unsupported
    render layout: false
  end
  
end