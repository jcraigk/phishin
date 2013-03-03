class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :random_lyrical_excerpt  # Pull lyrical excerpt unless XHR request
  
  def random_lyrical_excerpt
    @random_song = Song.random_lyrical_excerpt.first unless request.xhr?
  end
  
  def require_xhr!
    redirect_to(:root, alert: "You're doing it wrong") and return unless request.xhr?
  end
  
  def is_user_signed_in
    render :json => { success: user_signed_in?, msg: 'You must sign in to do that' }
  end
  
end
