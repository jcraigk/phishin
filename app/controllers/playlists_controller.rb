# frozen_string_literal: true
class PlaylistsController < ApplicationController
  def active_playlist
    activate_saved_playlist(Playlist.find_by!(slug: params[:slug])) if params[:slug]
    handle_playlist_session
    fetch_my_saved_playlists

    render_xhr_without_layout
  end

  def saved_playlists
    if current_user
      @playlists =
        fetch_saved_playlists.includes(:user)
                             .order(order_by_for_saved_playlists)
                             .page(params[:page])
    end

    render_xhr_without_layout
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
      render_json_failure(msg)
    end
  end

  def destroy_playlist
    if current_user && params[:id] && (playlist = Playlist.where(id: params[:id], user: current_user).first)
      playlist.destroy
      return render_json_success(msg: 'Playlist deleted')
    end

    render_json_failure('Invalid delete request')
  end

  def bookmark_playlist
    if current_user && params[:id].present?
      if PlaylistBookmark.where(playlist_id: params[:id], user: current_user).first.present?
        return render_json_failure('Playlist already bookmarked')
      end

      PlaylistBookmark.create(playlist_id: params[:id], user: current_user)
      return render_json_success(msg: 'Playlist bookmarked')
    end

    render_json_failure("Error fetching ID #{params[:id]}")
  end

  def unbookmark_playlist
    if current_user &&
       params[:id] &&
       (bookmark = PlaylistBookmark.where(playlist_id: params[:id], user: current_user).first)
      bookmark.destroy
      return render_json_success(msg: 'Playlist unbookmarked')
    end

    render_json_failure('Playlist not bookmarked')
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
    render_json_success(msg: session[:playlist])
  end

  def add_track_to_playlist
    return render_json_failure('Track already in playlist') if session[:playlist].include?(params[:track_id].to_i)
    return render_json_failure('Playlists are limited to 100 tracks') if session[:playlist].size > 99
    if (track = Track.find(params[:track_id]))
      session[:playlist] << track.id
      session[:playlist_shuffled].insert(rand(0..session[:playlist_shuffled].size), track.id)
      return render json: { success: true }
    end

    render_json_failure('Invalid track provided for playlist')
  end

  def add_show_to_playlist
    clear_saved_playlist

    if (show = Show.where(id: params[:show_id]).includes(:tracks).order('tracks.position asc'))

      session[:playlist] += show.tracks.map(&:id)
      session[:playlist].uniq!.take(100)

      return render_json_success(msg: 'Tracks added to playlist')
    end

    render_json_failure('Invalid track provided for playlist')
  end

  def next_track_id
    return unless init_session_playlist

    if playlist_track_ids.last == params[:track_id].to_i
      if session[:loop]
        render_json_success(track_id: playlist_track_ids.first)
      else
        render_json_failure('End of playlist')
      end
    elsif (idx = playlist_track_ids.find_index(params[:track_id].to_i))
      render_json_success(track_id: playlist_track_ids[idx + 1])
    else
      render_json_failure('track_id not in playlist')
    end
  end

  def previous_track_id
    return unless init_session_playlist

    if playlist_track_ids.first == params[:track_id].to_i
      if session[:loop]
        render_json_success(track_id: playlist_track_ids.last)
      else
        render_json_failure('Beginning of playlist')
      end
    elsif (idx = playlist_track_ids.find_index(params[:track_id].to_i))
      render_json_success(track_id: playlist_track_ids[idx - 1])
    else
      render_json_failure('track_id not in playlist')
    end
  end

  def init_session_playlist
    session[:playlist] = params[:playlist].split(',').map(&:to_i) if params[:playlist].present?
    render_json_failure('No active playlist') if session[:playlist].empty?
    false
  end

  def playlist_track_ids
    @playlist_track_ids ||= session[:shuffle] ? session[:playlist_shuffled] : session[:playlist]
  end

  def render_json_success(data)
    render json: { success: true }.merge(data)
  end

  def render_json_failure(msg)
    render json: { success: false, msg: msg }
  end

  def bookmark_ids
    @bookmark_ids ||= PlaylistBookmark.where(user: current_user).map(&:playlist_id)
  end

  def submit_playback_loop
    session[:loop], msg =
      if params[:loop] == 'true'
        [true, 'Playback looping enabled']
      else
        [false, 'Playback looping disabled']
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

  def handle_playlist_session
    return unless session[:playlist]
    @tracks = session[:playlist].map { |id| tracks_by_id[id] }
    @tracks_likes = user_likes_for_tracks(@tracks)
    @duration = @tracks.map(&:duration).inject(0, &:+)
  end

  def tracks_by_id
    @tracks_by_id ||= Track.where(id: session[:playlist]).includes(:show, :tags).index_by(&:id)
  end

  def fetch_my_saved_playlists
    return [] unless current_user
    @saved_playlists = Playlist.where(user: current_user).order(name: :asc)
  end

  def fetch_saved_playlists
    if params[:filter] == 'phriends'
      Playlist.where(id: bookmarked_ids)
    elsif params[:filter] == 'mine'
      Playlist.where(user: current_user)
    else
      Playlist.where('user_id = ? OR id IN (?)', current_user.id, bookmarked_ids)
    end
  end

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

  def track_ids
    @track_ids ||= playlist.playlist_tracks.order(position: :asc).map(&:track_id)
  end

  def retrieve_bookmark(playlist)
    bookmark = PlaylistBookmark.where(playlist_id: playlist.id, user: current_user).first
    session[:playlist_is_bookmarked] = bookmark.present?
  end
end
