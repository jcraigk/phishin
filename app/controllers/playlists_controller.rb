class PlaylistsController < ApplicationController

  def playlist
    @num_tracks = 0
    @duration = 0
    if session['playlist']
      tracks_by_id = Track.find(session['playlist']).index_by(&:id)
      @tracks = session['playlist'].collect {|id| tracks_by_id[id] }
      @num_tracks = @tracks.size
      @duration = @tracks.map(&:duration).inject(0, &:+)
    end
    render layout: false if request.xhr?
  end
  
  def reset_playlist
    if track = Track.where(id: params[:track_id]).first
      tracks = Track.where(show_id: track.show_id).order(:position).all
      session[:playlist] = tracks.map(&:id)
      render json: { success: true }
    else
      render json: { success: false }
    end
  end
  
  def update_current_playlist
    session[:playlist] = params[:track_ids]
    render json: { success: true, msg: session[:playlist] }
  end
  
  def add_track_to_playlist
  end
  
  def next_track_id
    playlist = session['playlist']
    idx = false
    playlist.each_with_index { |track_id, i| idx = i if track_id.to_s == params[:track_id].to_s }
    if idx
      if playlist.last.to_s == params[:track_id]
        if session['loop']
          next_track = playlist.first
          render json: { success: true, track_id: next_track}
        else
          render json: { success: false, msg: 'End of playlist' }
        end
      else
        next_track = playlist[idx+1]
        render json: { success: true, track_id: next_track}
      end
    else
      render json: { success: false, msg: 'track_id not in playlist'}
    end
  end

  def previous_track_id
    playlist = session['playlist']
    idx = false
    playlist.each_with_index { |track_id, i| idx = i if track_id.to_s == params[:track_id] }
    if idx
      if playlist.first.to_s == params[:track_id].to_s
        if session['loop']
          prev_track = playlist.last
          render json: { success: true, track_id: prev_track}
        else
          render json: { success: false, msg: 'Beginning of playlist' }
        end
      else
        prev_track = playlist[idx-1]
        render json: { success: true, track_id: prev_track}
      end
    else
      render json: { success: false, msg: 'track_id not in playlist'}
    end
  end
  
  def track_info
    track = Track.where(id: params[:track_id]).includes(:show => :venue).first
    if track
      render json: {
        success: true,
        title: track.title,
        show: "#{track.show.date}",
        show_url: "#{track.show.date}",
        venue: "#{track.show.venue.name}",
        venue_url: "/#{track.show.venue.slug}",
        city: track.show.venue.location,
        city_url: "/cities"
      }
    else
      render json: { success: false }
    end
  end
  
end