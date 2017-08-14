class PlaylistsController < ApplicationController
  def active_playlist
    @num_tracks = 0
    @duration = 0
    @invalid_playlist_slug = false

    if params[:slug]
      playlist = Playlist.where(slug: params[:slug]).first
      if playlist.present?
        activate_playlist(playlist)
      else
        @invalid_playlist_slug = true
      end
    end

    if session[:playlist]
      session[:playlist] = session[:playlist].take(100)
      session[:playlist_shuffled] = session[:playlist].shuffle
      tracks_by_id = Track.where(id: session[:playlist]).includes(:show, :tags).index_by(&:id)
      @tracks = session[:playlist].map { |id| tracks_by_id[id] }
      @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
      @num_tracks = @tracks.size
      @duration = @tracks.map(&:duration).inject(0, &:+) if @num_tracks > 0
    end

    @saved_playlists = Playlist.where(user_id: current_user.id).order('name') if current_user

    render layout: false if request.xhr?
  end

  def saved_playlists
    if current_user
      bookmarked_ids = PlaylistBookmark.where(user_id: current_user.id).all.map(&:playlist_id)
      if params[:filter] == 'phriends'
        @playlists = Playlist.where(id: bookmarked_ids)
      elsif params[:filter] == 'mine'
        @playlists = Playlist.where(user_id: current_user.id)
      else
        @playlists = Playlist.where("user_id = ? OR id IN (?)", current_user.id, bookmarked_ids)
      end
      @playlists.includes(:user).order(order_by_for_saved_playlists).page(params[:page])
    end

    render layout: false if request.xhr?
  end

  def save_playlist
    success = false
    save_action = %w(new existing).include?(params[:save_action]) ? params[:save_action] : 'new'

    # TODO: Could we do the following with AR validations more cleanly?
    if !current_user
      msg = 'You must be logged in to save playlists'
    elsif session[:playlist].size < 2
      msg = 'Saved playlists must contain at least 2 tracks'
    elsif params[:name].empty? || params[:slug].empty? || params[:name].empty? || params[:slug].empty?
      msg = 'You must provide a name and URL for this playlist'
    elsif !params[:name].match(/^.{5,50}$/)
      msg = 'Name must be between 5 and 50 characters'
    elsif !params[:slug].match(/^[a-z0-9\-]{5,50}$/)
      msg = 'URL must be between 5 and 50 lowercase letters, numbers, or dashes'
    elsif save_action == 'new'
      if Playlist.where(user_id: current_user.id).all.size >= MAX_PLAYLISTS_PER_USER
        msg = "Sorry, each user is limited to #{MAX_PLAYLISTS_PER_USER} playlists"
      elsif Playlist.where(name: params[:name], user_id: current_user.id).first
        msg = 'That name has already been taken; choose another'
      elsif Playlist.where(slug: params[:slug]).first
        msg = 'That URL has already been taken; choose another'
      else
        playlist = Playlist.create(user_id: current_user.id, name: params[:name], slug: params[:slug])
        create_playlist_tracks(playlist)
        activate_playlist(playlist)
        success = true
        msg = 'Playlist saved'
      end
    elsif (playlist = Playlist.where(user_id: current_user.id, id: params[:id]).first)
      playlist.update_attributes(name: params[:name], slug: params[:slug])
      playlist.playlist_tracks.map(&:destroy)
      create_playlist_tracks(playlist)
      activate_playlist(playlist)
      success = true
      msg = 'Playlist saved'
    else
      msg = 'Playlist not found'
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

  def destroy_playlist
    if current_user && params[:id] && (playlist = Playlist.where(id: params[:id], user_id: current_user.id).first)
      playlist.destroy
      render json: { success: true, msg: 'Playlist deleted' }
      return
    end

    render json: { success: false, msg: 'Invalid delete request' }
  end

  def bookmark_playlist
    if current_user && params[:id].present?
      if (bookmark = PlaylistBookmark.where(playlist_id: params[:id], user_id: current_user.id).first)
        render json: { success: false, msg: 'Playlist already bookmarked' }
        return
      end

      PlaylistBookmark.create(playlist_id: params[:id], user_id: current_user.id)
      render json: { success: true, msg: 'Playlist bookmarked' }
      return
    end

    render json: { success: false, msg: "Error fetching ID #{params[:id]}" }
  end

  def unbookmark_playlist
    if current_user && params[:id] && bookmark = PlaylistBookmark.where(playlist_id: params[:id], user_id: current_user.id).first
      bookmark.destroy
      render json: { success: true, msg: 'Playlist unbookmarked' }
      return
    end

    render json: { success: false, msg: 'Playlist not bookmarked' }
  end

  def clear_playlist
    clear_saved_playlist
    session[:playlist] = []
    session[:playlist_shuffled] = []
    render json: { success: true }
  end

  def reset_playlist
    clear_saved_playlist
    if (track = Track.where(id: params[:track_id]).first)
      tracks = Track.where(show_id: track.show_id).order(:position).all
      session[:playlist] = tracks.map(&:id)
      session[:playlist_shuffled] = session[:playlist].shuffle
      render json: { success: true }
    else
      render json: { success: false }
    end
  end

  def update_active_playlist
    clear_saved_playlist
    session[:playlist] = params[:track_ids].map { |id| Integer(id, 10) }
    session[:playlist] = session[:playlist].take(100)
    session[:playlist_shuffled] = session[:playlist].shuffle
    render json: { success: true, msg: session[:playlist] }
  end

  def add_track_to_playlist
    if session[:playlist].include? Integer(params[:track_id], 10)
      render json: { success: false, msg: 'Track already in playlist' }
      return
    end

    if session[:playlist].size > 99
      render json: { success: false, msg: 'Playlists are limited to 100 tracks' }
    elsif (track = Track.find(params[:track_id]))
      session[:playlist] << track.id
      render json: { success: true }
    else
      render json: { success: false, msg: 'Invalid track provided for playlist' }
    end
  end

  def add_show_to_playlist
    clear_saved_playlist
    if (show = Show.where(id: params[:show_id]).includes(:tracks).order('tracks.position asc').first)
      track_list = show.tracks.map(&:id)
      unique_list = []
      track_list.each { |track_id| unique_list << track_id unless session[:playlist].include? track_id }
      if session[:playlist].size + unique_list.size > 99
        render json: { success: false, msg: 'Playlists are limited to 100 tracks' }
      elsif unique_list.empty?
        render json: { success: false, msg: 'Tracks already in playlist' }
      elsif unique_list != track_list
        session[:playlist] += unique_list
        render json: { success: true, msg: 'Some duplicate tracks not added' }
      else
        session[:playlist] += unique_list
        render json: { success: true, msg: 'Tracks added to playlist' }
      end
    else
      render json: { success: false, msg: 'Invalid show provided for playlist' }
    end
  end

  def next_track_id
    render json: { success: false, msg: 'No active playlist' } && return if session[:playlist].empty?

    playlist = session[:shuffle] ? session[:playlist_shuffled] : session[:playlist]
    idx = false
    playlist.each_with_index { |track_id, i| idx = i if track_id.to_s == params[:track_id].to_s }

    render json: { success: true, track_id: playlist.first } && return unless idx

    if playlist.last.to_s == params[:track_id]
      if session[:loop]
        render json: { success: true, track_id: playlist.first }
      else
        render json: { success: false, msg: 'End of playlist' }
      end
    else
      render json: { success: true, track_id: playlist[idx + 1] }
    end
  end

  def previous_track_id
    render json: { success: false, msg: 'No active playlist' } && return if session[:playlist].empty?

    playlist = session[:shuffle] ? session[:playlist_shuffled] : session[:playlist]
    idx = false
    playlist.each_with_index { |track_id, i| idx = i if track_id.to_s == params[:track_id].to_s }
    render json: { success: false, msg: 'track_id not in playlist' } && return unless idx

    if playlist.first.to_s == params[:track_id].to_s
      if session[:loop]
        render json: { success: true, track_id: playlist.last }
      else
        render json: { success: false, msg: 'Beginning of playlist' }
      end
    else
      render json: { success: true, track_id: playlist[idx - 1] }
    end
  end

  def submit_playback_loop
    if params[:loop] == 'true'
      session[:loop] = true
      msg = 'Playback looping enabled'
    else
      session[:loop] = false
      msg = 'Playback looping disabled'
    end

    render json: { success: true, msg: msg }
  end

  def submit_playback_shuffle
    if params[:shuffle] == 'true'
      session[:shuffle] = true
      msg = 'Playback shuffling enabled'
    else
      session[:shuffle] = false
      msg = 'Playback shuffling disabled'
    end
    render json: { success: true, msg: msg }
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

  def random_song_track
    if (song = Song.where(id: params[:song_id]).first)
      track = song.tracks.all.sample
      show = Show.where(id: track.show_id).first
    else
      render json: { success: false, msg: 'Invalid song_id' }
    end

    render json: {
      success: true,
      url: "/#{show.date}",
      track_id: track.id
    }
  end

  def playlist
    render json: { playlist: session[:playlist] }
  end

  private

  def order_by_for_saved_playlists
    params[:sort] = 'name' unless %w(name duration username).include?(params[:sort])

    order_by = if %w(name duration).include?(params[:sort])
                 params[:sort]
               elsif params[:sort] == 'username'
                 'users.username'
               end
    order_by += ', name'

    order_by
  end

  def create_playlist_tracks(playlist)
    session[:playlist].each_with_index do |track_id, idx|
      PlaylistTrack.create(playlist_id: playlist.id, track_id: track_id, position: idx + 1)
    end
    playlist.update_attributes(duration: playlist.tracks.map(&:duration).inject(0, &:+))
  end

  def activate_playlist(playlist)
    session.merge(
      playlist: playlist.playlist_tracks.order('position').all.map(&:track_id),
      playlist_shuffled: session[:playlist].shuffle,
      playlist_id: playlist.id,
      playlist_name: playlist.name,
      playlist_slug: playlist.slug,
      playlist_user_id: playlist.user.id,
      playlist_username: playlist.user.username
    )
    retrieve_bookmark if current_user
  end

  def retrieve_bookmark
    bookmark = PlaylistBookmark.where(playlist_id: playlist.id, user_id: current_user.id).first
    session[:playlist_is_bookmarked] = bookmark.present?
  end

  def clear_saved_playlist
    session.merge(
      playlist: [],
      playlist_shuffled: [],
      playlist_id: 0,
      playlist_name: '',
      playlist_slug: '',
      playlist_user_id: '',
      playlist_username: '',
      playlist_is_bookmarked: false
    )
  end
end
