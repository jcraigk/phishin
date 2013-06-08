class ApplicationController < ActionController::Base
  
  include ApplicationHelper
  protect_from_forgery
  
  # before_filter :artificial_wait if Rails.env == "development"
  before_filter :random_lyrical_excerpt  # Pull lyrical excerpt unless XHR request
  before_filter :authenticate
  before_filter :init_session
  before_filter :init_params
  # before_filter :mobile_unsupported
  before_filter :require_xhr
  
  def random_lyrical_excerpt
    unless request.xhr?
      @random_song = Song.random_lyrical_excerpt.first
      # raise @random_song.inspect
    end
  end
  
  def require_xhr!
    redirect_to(:root, alert: "You're doing it wrong") and return unless request.xhr?
  end
  
  def is_user_signed_in
    render :json => { success: user_signed_in?, msg: "Hello" }
  end
  
  def get_user_track_like(track)
    track.likes.where(user_id: current_user.id).first if track and track.likes and current_user
  end
  
  protected
  
  def get_user_show_like(show)
    show.likes.where(user_id: current_user.id).first if show and current_user
  end
  
  private
  
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
  
  def init_session
    session[:playlist]            ||= []
    session[:playlist_id]         ||= 0
    session[:playlist_name]       ||= ''
    session[:playlist_slug]       ||= ''
    session[:playlist_user_id]    ||= ''
    session[:playlist_username]  ||= ''
    session[:loop]                ||= false
    session[:randomize]           ||= false
  end
  
  def init_params
    params[:t]                ||= 0
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
