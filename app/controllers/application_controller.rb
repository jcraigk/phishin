class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :random_lyrical_excerpt  # Pull lyrical excerpt unless XHR request
  
  def random_lyrical_excerpt
    @random_song = Song.random_lyrical_excerpt.first unless request.xhr?
  end
  
end
