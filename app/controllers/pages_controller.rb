class PagesController < ApplicationController
  
  def legal_stuff
    request.xhr? ? (render layout: false) : (render)
  end

  def contact_us
    request.xhr? ? (render layout: false) : (render)
  end
  
end