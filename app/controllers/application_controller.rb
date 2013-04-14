class ApplicationController < ActionController::Base
  
  include ApplicationHelper
  protect_from_forgery
  
  # before_filter :artificial_wait if Rails.env == "development"
  before_filter :random_lyrical_excerpt  # Pull lyrical excerpt unless XHR request
  before_filter :authenticate
  before_filter :setup_session
  before_filter :mobile_unsupported
  before_filter :require_xhr
  
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
    sleep 1.second
  end
  
  def setup_session
    session[:playlist]    ||= []
    session[:loop]        ||= false
    session[:randomize]   ||= false
    params[:per_page]     ||= 10
    params[:t]            ||= 0
  end
  
  def mobile_unsupported
    if request.env["HTTP_USER_AGENT"] =~ /Android|webOS|iPhone|iPad|iPod|BlackBerry/i
      redirect_to mobile_unsupported_path and return
    end
  end
  
  def require_xhr
    unless request.xhr? or xhr_exempt_controller
      render 'layouts/application', layout: false and return
    end
  end
  
end
