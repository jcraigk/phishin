class PlaylistsController < ApplicationController

  def playlist
    if session['playlist']
      tracks_by_id = Track.find(session['playlist']).index_by(&:id) # Gives you a hash indexed by ID
      @tracks = session['playlist'].collect {|id| tracks_by_id[Integer(id,10)] }
      @duration = @tracks.map(&:duration).inject(0, &:+)
    end
    render layout: false if request.xhr?
  end

  def update_current_playlist
    session[:playlist] = params[:track_ids]
    render json: { success: true, msg: session[:playlist] }
  end
  
end