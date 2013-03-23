class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :random_lyrical_excerpt  # Pull lyrical excerpt unless XHR request
  before_filter :authenticate
  # before_filter :artificial_wait
  before_filter :setup_session
  
  def random_lyrical_excerpt
    @random_song = Song.random_lyrical_excerpt.first unless request.xhr?
  end
  
  def require_xhr!
    redirect_to(:root, alert: "You're doing it wrong") and return unless request.xhr?
  end
  
  def is_user_signed_in
    render :json => { success: user_signed_in?, msg: "Hello" }
  end
  
  protected
  
  def authenticate
    if Rails.env == 'production'
      authenticate_or_request_with_http_basic do |username, password|
        username == HTAUTH_USERNAME and password == HTAUTH_PASSWORD
      end
    end
  end
  
  def artificial_wait
    sleep 3.seconds
  end
  
  def setup_session
    session[:playlist]    ||= []
    session[:loop]        ||= false
    session[:randomize]   ||= false
    params[:per_page]     ||= 10
  end
  
end
