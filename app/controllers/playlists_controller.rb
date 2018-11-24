# frozen_string_literal: true
class PlaylistsController < ApplicationController
  def active_playlist
    @num_tracks = 0
    @duration = 0
    @invalid_playlist_slug = false

    if params[:slug]
      if (playlist = Playlist.where(slug: params[:slug]).first)
        activate_saved_playlist(playlist)
      else
        @invalid_playlist_slug = true
      end
    end

    if session[:playlist]
      tracks_by_id = Track.where(id: session[:playlist]).includes(:show, :tags).index_by(&:id)
      @tracks = session[:playlist].map { |id| tracks_by_id[id] }
      # @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
      @tracks_likes = []
      @duration = @tracks.map(&:duration).inject(0, &:+)
    end

    @saved_playlists = Playlist.where(user: current_user).order(name: :asc) if current_user

    render layout: false if request.xhr?
  end

  def saved_playlists
    if current_user
      bookmarked_ids = PlaylistBookmark.where(user: current_user).map(&:playlist_id)
      @playlists =
        if params[:filter] == 'phriends'
          Playlist.where(id: bookmarked_ids)
        elsif params[:filter] == 'mine'
          Playlist.where(user: current_user)
        else
          Playlist.where('user_id = ? OR id IN (?)', current_user.id, bookmarked_ids)
        end
      @playlists =
        @playlists.includes(:user)
                  .order(order_by_for_saved_playlists)
                  .page(params[:page])
    end

    render layout: false if request.xhr?
  end

  def save_playlist
    success = false
    save_action = params[:save_action].in?(%w[new existing]) ? params[:save_action] : 'new'

    # TODO: Could we do the following with AR validations more cleanly?
    if !current_user
      msg = 'You must be logged in to save playlists'
    elsif session[:playlist].size < 2
      msg = 'Saved playlists must contain at least 2 tracks'
    elsif params[:name].empty? || params[:slug].empty? || params[:name].empty? || params[:slug].empty?
      msg = 'You must provide a name and URL for this playlist'
    elsif !params[:name].match(/\A.{5,50}\z/)
      msg = 'Name must be between 5 and 50 characters'
    elsif !params[:slug].match(/\A[a-z0-9\-]{5,50}\z/)
      msg = 'URL must be between 5 and 50 lowercase letters, numbers, or dashes'
    elsif save_action == 'new'
      if Playlist.where(user: current_user).count >= MAX_PLAYLISTS_PER_USER
        msg = "Sorry, each user is limited to #{MAX_PLAYLISTS_PER_USER} playlists"
      elsif Playlist.where(name: params[:name], user: current_user).first
        msg = 'That name has already been taken; choose another'
      elsif Playlist.where(slug: params[:slug]).first
        msg = 'That URL has already been taken; choose another'
      else
        playlist = Playlist.create(user: current_user, name: params[:name], slug: params[:slug])
        create_playlist_tracks(playlist)
        activate_saved_playlist(playlist)
        success = true
        msg = 'Playlist saved'
      end
    elsif (playlist = Playlist.where(user: current_user, id: params[:id]).first)
      playlist.update_attributes(name: params[:name], slug: params[:slug])
      playlist.playlist_tracks.map(&:destroy)
      create_playlist_tracks(playlist)
      activate_saved_playlist(playlist)
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
    if current_user && params[:id] && (playlist = Playlist.where(id: params[:id], user: current_user).first)
      playlist.destroy
      render json: { success: true, msg: 'Playlist deleted' }
      return
    end

    render json: { success: false, msg: 'Invalid delete request' }
  end

  def bookmark_playlist
    if current_user && params[:id].present?
      if PlaylistBookmark.where(playlist_id: params[:id], user: current_user).first.present?
        render json: { success: false, msg: 'Playlist already bookmarked' }
        return
      end

      PlaylistBookmark.create(playlist_id: params[:id], user: current_user)
      render json: { success: true, msg: 'Playlist bookmarked' }
      return
    end

    render json: { success: false, msg: "Error fetching ID #{params[:id]}" }
  end

  def unbookmark_playlist
    if current_user &&
       params[:id] &&
       (bookmark = PlaylistBookmark.where(playlist_id: params[:id], user: current_user).first)
      bookmark.destroy
      render json: { success: true, msg: 'Playlist unbookmarked' }
      return
    end

    render json: { success: false, msg: 'Playlist not bookmarked' }
  end

  def clear_playlist
    clear_saved_playlist
    render json: { success: true }
  end

  def reset_playlist
    clear_saved_playlist

    success = false
    if (track = Track.where(id: params[:track_id]).first)
      session[:playlist] = track.show.tracks.order(:position).map(&:id)
      session[:playlist_shuffled] = session[:playlist].shuffle
      success = true
    end

    render json: { success: success, playlist: session[:playlist] }
  end

  def update_active_playlist
    clear_saved_playlist
    session[:playlist] = params[:track_ids].map(&:to_i).take(100)
    session[:playlist_shuffled] = session[:playlist].shuffle
    render json: { success: true, msg: session[:playlist] }
  end

  def add_track_to_playlist
    if session[:playlist].include?(params[:track_id].to_i)
      render json: { success: false, msg: 'Track already in playlist' }
      return
    end

    if session[:playlist].size > 99
      render json: { success: false, msg: 'Playlists are limited to 100 tracks' }
    elsif (track = Track.find(params[:track_id]))
      session[:playlist] << track.id
      session[:playlist_shuffled].insert(rand(0..session[:playlist_shuffled].size), track.id)
      render json: { success: true }
    else
      render json: { success: false, msg: 'Invalid track provided for playlist' }
    end
  end

  def add_show_to_playlist
    clear_saved_playlist

    if (show = Show.where(id: params[:show_id]).includes(:tracks).order('tracks.position asc'))

      session[:playlist] += show.tracks.map(&:id)
      session[:playlist].uniq!.take(100)

      render json: { success: true, msg: 'Tracks added to playlist' }
    else
      render json: { success: false, msg: 'Invalid show provided for playlist' }
    end
  end

  def next_track_id
    session[:playlist] = params[:playlist].split(',').map(&:to_i) if params[:playlist].present?

    if session[:playlist].empty?
      render json: { success: false, msg: 'No active playlist' }
      return
    end

    playlist_track_ids = session[:shuffle] ? session[:playlist_shuffled] : session[:playlist]

    if playlist_track_ids.last == params[:track_id].to_i
      if session[:loop]
        render json: { success: true, track_id: playlist_track_ids.first }
      else
        render json: { success: false, msg: 'End of playlist' }
      end
    elsif (idx = playlist_track_ids.find_index(params[:track_id].to_i))
      render json: { success: true, track_id: playlist_track_ids[idx + 1] }
    else
      render json: { success: false, msg: 'track_id not in playlist' }
    end
  end

  def previous_track_id
    session[:playlist] = params[:playlist].split(',').map(&:to_i) if params[:playlist].present?

    if session[:playlist].empty?
      render json: { success: false, msg: 'No active playlist' }
      return
    end

    playlist_track_ids = session[:shuffle] ? session[:playlist_shuffled] : session[:playlist]

    if playlist_track_ids.first == params[:track_id].to_i
      if session[:loop]
        render json: { success: true, track_id: playlist_track_ids.last }
      else
        render json: { success: false, msg: 'Beginning of playlist' }
      end
    elsif (idx = playlist_track_ids.find_index(params[:track_id].to_i))
      render json: { success: true, track_id: playlist_track_ids[idx - 1] }
    else
      render json: { success: false, msg: 'track_id not in playlist' }
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
    render json: {
      success: true,
      url: "/#{show.date}",
      track_id: show.tracks.order(position: :asc).first.id
    }
  end

  def random_song_track
    if (song = Song.where(id: params[:song_id]).first)
      track = song.tracks.sample
      show = Show.where(id: track.show_id).first

      render json: {
        success: true,
        url: "/#{show.date}",
        track_id: track.id
      }
    else
      render json: { success: false, msg: 'Invalid song_id' }
    end
  end

  def playlist
    render json: { playlist: session[:playlist] }
  end

  private

  def order_by_for_saved_playlists
    params[:sort] = 'name' unless params[:sort].in?(%w[name duration])
    params[:sort] + ' asc'
  end

  def create_playlist_tracks(playlist)
    session[:playlist].each_with_index do |track_id, idx|
      PlaylistTrack.create(
        playlist_id: playlist.id,
        track_id: track_id,
        position: idx + 1
      )
    end
    playlist.update(duration: playlist.tracks.map(&:duration).inject(0, &:+))
  end

  def activate_saved_playlist(playlist)
    track_ids = playlist.playlist_tracks.order(position: :asc).map(&:track_id)
    session.update(
      playlist: track_ids,
      playlist_shuffled: track_ids.shuffle,
      playlist_id: playlist.id,
      playlist_name: playlist.name,
      playlist_slug: playlist.slug,
      playlist_user_id: playlist.user.id,
      playlist_username: playlist.user.username
    )

    retrieve_bookmark(playlist) if current_user
  end

  def retrieve_bookmark(playlist)
    bookmark = PlaylistBookmark.where(playlist_id: playlist.id, user: current_user).first
    session[:playlist_is_bookmarked] = bookmark.present?
  end

  def clear_saved_playlist
    session.update(
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
