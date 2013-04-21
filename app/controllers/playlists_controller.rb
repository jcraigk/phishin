class PlaylistsController < ApplicationController

  def playlist
    @num_tracks = 0
    @duration = 0
    if params[:slug] and playlist = Playlist.where(slug: params[:slug]).first
      session[:playlist] = playlist.tracks.order('position').all.map(&:id)
      session[:playlist_id] = playlist.id
      session[:playlist_name] = playlist.name
      session[:playlist_slug] = playlist.slug
      session[:playlist_user_id] = playlist.user.id
      session[:playlist_user_name] = playlist.user.username
    end
    begin
      if session[:playlist]
        session[:playlist] = session[:playlist].take(100)
        tracks_by_id = Track.find(session[:playlist]).index_by(&:id)
        @tracks = session[:playlist].collect {|id| tracks_by_id[id] }
        @num_tracks = @tracks.size
        @duration = @tracks.map(&:duration).inject(0, &:+) if @num_tracks > 0
      end
    rescue
      session[:playlist] = []
    end
    @saved_playlists = Playlist.where(user_id: current_user.id).order('name') if current_user
    render layout: false if request.xhr?
  end
  
  def save_playlist
    success = false
    if ['new', 'existing'].include? params[:save_action]
      save_action = params[:save_action]
    else
      save_action = 'new'
    end
    # TODO Could we do the following with validations more cleanly?
    if !current_user
      msg = 'You must be logged in to save playlists'
    elsif !params[:name] or !params[:slug] or params[:name].empty? or params[:slug].empty?
      msg = 'You must provide a name and URL for this playlist'
    elsif !params[:name].match(/^.{5,50}$/)
      msg = 'Name must be between 5 and 50 characters'
    elsif !params[:slug].match(/^[a-z0-9\-]{5,50}$/)
      msg = 'URL must be between 5 and 50 lowercase letters, numbers, or dashes'
    elsif playlist = Playlist.where(name: params[:name], user_id: current_user.id).where('id <> ?', params[:id]).first
      msg = 'You already have a playlist with that name; choose another'
    elsif playlist = Playlist.where(slug: params[:slug]).where('id <> ?', params[:id]).first
      msg = 'That URL has already been taken; choose another'
    elsif session[:playlist].size < 2
      msg = 'Saved playlists must contain at least 2 tracks'
    elsif save_action == 'new'
      if Playlist.where(user_id: current_user.id).all.size >= 10
        msg = 'Sorry, each user is limited to 10 playlists'
      else
        playlist = Playlist.create(user_id: current_user.id, name: params[:name], slug: params[:slug])
        create_playlist_tracks(playlist.id)
        success = true
        msg = 'Playlist created'
      end
    elsif playlist = Playlist.where(user_id: current_user.id, id: params[:id]).first
      playlist.update_attributes(name: params[:name], slug: params[:slug])
      playlist.tracks.each { |track| track.destroy }
      create_playlist_tracks(playlist.id)
      success = true
      msg = 'Playlist updated'
    else
      msg = 'Existing playlist not found'
    end
    if success
      render json: {
        success: true,
        msg: msg,
        id: playlist.id,
        name: playlist.name,
        slug: playlist.slug
      }  
    else
      render json: { success: false, msg: msg }
    end
  end
  
  def delete_playlist
    if current_user and params[:id] and playlist = Playlist.where(id: params[:id], user_id: current_user.id).first
      playlist.destroy
      render json: { success: true }
    else
      render json: { success: false, msg: 'Invalid delete request' }
    end
  end
  
  def clear_playlist
    clear_saved_playlist
    session[:playlist] = []
    render json: { success: true }
  end
  
  def reset_playlist
    clear_saved_playlist
    if track = Track.where(id: params[:track_id]).first
      tracks = Track.where(show_id: track.show_id).order(:position).all
      session[:playlist] = tracks.map(&:id)
      render json: { success: true }
    else
      render json: { success: false }
    end
  end
  
  def update_current_playlist
    clear_saved_playlist
    session[:playlist] = params[:track_ids].map {|id| Integer(id, 10)}
    session[:playlist] = session[:playlist].take(100)
    render json: { success: true, msg: session[:playlist] }
  end
  
  def add_track_to_playlist
    clear_saved_playlist
    if session[:playlist].include? Integer(params[:track_id], 10)
      render json: { success: false, msg: 'Track already in playlist'}
    else
      if session[:playlist].size > 99
        render json: { success: false, msg: 'Playlists are limited to 100 tracks' }
      elsif track = Track.find(params[:track_id])
        session[:playlist] << track.id
        render json: { success: true }   
      else
        render json: { success: false, msg: 'Invalid track provided for playlist' }
      end
    end
  end

  def add_show_to_playlist
    clear_saved_playlist
    if show = Show.where(id: params[:show_id]).includes(:tracks).order('tracks.position asc').first
      track_list = show.tracks.map(&:id)
      unique_list = []
      track_list.each { |track_id| unique_list << track_id unless session[:playlist].include? track_id }
      if session[:playlist].size + unique_list.size > 99
        render json: { success: false, msg: 'Playlists are limited to 100 tracks' }
      else
        if unique_list.size == 0
          render json: { success: false, msg: 'Tracks already in playlist' }
        elsif unique_list != track_list
          session[:playlist] += unique_list
          render json: { success: true, msg: 'Some duplicate tracks not added' }
        else
          session[:playlist] += unique_list
          render json: { success: true, msg: 'Tracks added to playlist' }
        end
      end
    else
      render json: { success: false, msg: 'Invalid show provided for playlist' }
    end
  end
  
  def next_track_id
    if session[:playlist].size > 0
      playlist = session[:playlist]
      idx = false
      playlist.each_with_index { |track_id, i| idx = i if track_id.to_s == params[:track_id].to_s }
      if idx
        if session[:randomize]
          render json: { success: true, track_id: playlist.sample }
        else
          if playlist.last.to_s == params[:track_id]
            if session[:loop]
              render json: { success: true, track_id: playlist.first }
            else
              render json: { success: false, msg: 'End of playlist' }
            end
          else
            render json: { success: true, track_id: playlist[idx+1] }
          end
        end
      else
        # If no valid track_id passed in, return first item in playlist
        render json: { success: true, track_id: playlist.first }
      end
    else
      render json: { success: false, msg: 'No current playlist' }
    end
  end

  def previous_track_id
    playlist = session[:playlist]
    idx = false
    playlist.each_with_index { |track_id, i| idx = i if track_id.to_s == params[:track_id] }
    if idx
      if session[:randomize]
        render json: { success: true, track_id: playlist.sample }
      else
        if playlist.first.to_s == params[:track_id].to_s
          if session[:loop]
            render json: { success: true, track_id: playlist.last }
          else
            render json: { success: false, msg: 'Beginning of playlist' }
          end
        else
          render json: { success: true, track_id: playlist[idx-1] }
        end
      end
    else
      render json: { success: false, msg: 'track_id not in playlist' }
    end
  end
  
  def track_info
    track = Track.where(id: params[:track_id]).includes(:show => :venue).first
    liked = (current_user and track.likes.where(user_id: current_user.id).first ? true : false)
    if track
      render json: {
        success: true,
        id: track.id,
        title: track.title,
        duration: track.duration,
        show: "#{track.show.date}",
        show_url: "/#{track.show.date}",
        venue: "#{track.show.venue.name}",
        venue_url: "/#{track.show.venue.slug}",
        city: track.show.venue.location,
        city_url: "/map?term=#{CGI::escape(track.show.venue.location)}",
        likes_count: track.likes_count,
        liked: liked
      }
    else
      render json: { success: false }
    end
  end
  
  def submit_playlist_options
    params.reject! { |k,v| ! %w[randomize loop].include? k.to_s }
    params[:loop] == "true" ? session[:loop] = true : session[:loop] = false
    params[:randomize] == "true" ? session[:randomize] = true : session[:randomize] = false
    render json: { success: true}
  end
  
  def random_show
    show = Show.avail.random.first
    first_track = show.tracks.order('position asc').first
    render json: {
      success: true,
      url: "/#{show.date}",
      track_id: first_track.id
    }
  end
  
  def get_playlist
    render json: { playlist: session[:playlist] }
  end
  
  def get_saved_playlists
    if current_user
      playlists = Playlist.where(user_id: current_user.id).order('name asc').all
      render json: {success: true, playlists: playlists.to_json(except: [:user_id, :created_at, :updated_at]) }
    else
      render json: { success: false }
    end
  end
  
  private
  
  def create_playlist_tracks(playlist_id)
    session[:playlist].each_with_index do |track_id, idx|
      PlaylistTrack.create(playlist_id: playlist_id, track_id: track_id, position: idx+1)
    end
  end
  
  def clear_saved_playlist
    session[:playlist_id] = 0
    session[:playlist_name] = ''
    session[:playlist_slug] = ''
    session[:playlist_user_id] = ''
    session[:playlist_user_name] = ''
  end
  
end