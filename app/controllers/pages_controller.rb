class PagesController < ApplicationController
  
  def legal_stuff
    render layout: false if request.xhr?
  end

  def contact_us
    render layout: false if request.xhr?
  end
  
end