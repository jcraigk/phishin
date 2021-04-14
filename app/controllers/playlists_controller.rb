# frozen_string_literal: true
class PlaylistsController < ApplicationController
  before_action :init_session_playlist
  before_action :authenticate_user!,
                only: %i[save_playlist destroy_playlist bookmark_playlist unbookmark_playlist]

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
      tracks_by_id = Track.where(id: session[:playlist]).includes(:show, track_tags: :tag).index_by(&:id)
      @tracks = session[:playlist].map { |id| tracks_by_id[id] }
      @tracks_likes = user_likes_for_tracks(@tracks)
      @duration = @tracks.sum(&:duration)
    end

    @saved_playlists = Playlist.where(user: current_user).order(name: :asc) if current_user

    render layout: false if request.xhr?
  end

  def saved_playlists
    if current_user
      bookmarked_ids = PlaylistBookmark.where(user: current_user).map(&:playlist_id)
      @playlists =
        case params[:filter]
        when 'phriends' then Playlist.where(id: bookmarked_ids)
        when 'mine' then Playlist.where(user: current_user)
        else Playlist.where('user_id = ? OR id IN (?)', current_user.id, bookmarked_ids)
        end
      @playlists =
        @playlists.includes(:user)
                  .order(order_by_for_saved_playlists)
                  .page(params[:page])
    else
      @playlists = []
    end

    render layout: false if request.xhr?
  end

  def save_playlist
    save_action = params[:save_action].in?(%w[new existing]) ? params[:save_action] : 'new'

    if save_action == 'new'
      if Playlist.where(user: current_user).count >= MAX_PLAYLISTS_PER_USER
        return render(
          json: {
            success: false,
            msg: "Sorry, each user is limited to #{MAX_PLAYLISTS_PER_USER} playlists"
          }
        )
      end

      playlist = Playlist.create(user: current_user, name: params[:name], slug: params[:slug])
      return render_bad_playlist(playlist) unless playlist.valid?
    else
      playlist = Playlist.find_by!(user: current_user, id: params[:id])
      playlist.update(name: params[:name], slug: params[:slug])
      return render_bad_playlist(playlist) unless playlist.valid?
      playlist.playlist_tracks.map(&:destroy)
    end

    refresh_playlist(playlist)
    render_good_playlist(playlist)
  end

  def destroy_playlist
    if current_user && params[:id] && (playlist = fetch_playlist)
      playlist.destroy
      return render json: { success: true, msg: 'Playlist deleted' }
    end

    render json: { success: false, msg: 'Invalid delete request' }
  end

  def fetch_playlist
    Playlist.find_by(id: params[:id], user: current_user)
  end

  def bookmark_playlist
    if current_user && params[:id].present?
      if PlaylistBookmark.where(playlist_id: params[:id], user: current_user).first.present?
        return render json: { success: false, msg: 'Playlist already bookmarked' }
      end

      PlaylistBookmark.create(playlist_id: params[:id], user: current_user)
      return render json: { success: true, msg: 'Playlist bookmarked' }
    end

    render json: { success: false, msg: "Error fetching ID #{params[:id]}" }
  end

  def unbookmark_playlist
    if current_user &&
       params[:id] &&
       (bookmark = PlaylistBookmark.where(playlist_id: params[:id], user: current_user).first)
      bookmark.destroy
      return render json: { success: true, msg: 'Playlist unbookmarked' }
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
      return render json: { success: false, msg: 'Track already in playlist' }
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

    if (show = Show.published.find_by(id: params[:show_id]))

      session[:playlist] += show.tracks.sort_by(&:position).map(&:id)
      session[:playlist] = session[:playlist].uniq.take(100)

      render json: { success: true, msg: 'Tracks added to playlist' }
    else
      render json: { success: false, msg: 'Invalid show provided for playlist' }
    end
  end

  def next_track_id
    session[:playlist] = params[:playlist].split(',').map(&:to_i) if params[:playlist].present?

    return render json: { success: false, msg: 'No active playlist' } if session[:playlist].blank?

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

    return render json: { success: false, msg: 'No active playlist' } if session[:playlist].blank?

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
    show = Show.published.random.first
    render json: {
      success: true,
      url: "/#{show.date}",
      track_id: show.tracks.order(position: :asc).first.id
    }
  end

  def random_song_track
    if (song = Song.where(id: params[:song_id]).first)
      track = song.tracks.sample
      show = Show.published.find_by(id: track.show_id)
      render json: { success: true, url: "/#{show.date}", track_id: track.id }
    else
      render json: { success: false, msg: 'Invalid song_id' }
    end
  end

  def playlist
    render json: { playlist: session[:playlist] }
  end

  private

  def render_bad_playlist(playlist)
    render json: { success: false, msg: playlist.errors.full_messages.join(', ') }
  end

  def render_good_playlist(playlist)
    render json: {
      success: true,
      msg: 'Playlist saved',
      id: playlist.id,
      name: playlist.name,
      slug: playlist.slug
    }
  end

  def refresh_playlist(playlist)
    create_playlist_tracks(playlist)
    activate_saved_playlist(playlist)
  end

  def order_by_for_saved_playlists
    params[:sort] = 'name' unless params[:sort].in?(%w[name duration])
    "#{params[:sort]} asc"
  end

  def create_playlist_tracks(playlist)
    session[:playlist].each_with_index do |track_id, idx|
      PlaylistTrack.create(
        playlist_id: playlist.id,
        track_id: track_id,
        position: idx + 1
      )
    end
    playlist.update(duration: playlist.tracks.sum(&:duration))
  end

  def activate_saved_playlist(playlist)
    update_playlist(playlist)
    retrieve_bookmark(playlist) if current_user
  end

  def update_playlist(playlist)
    track_ids = playlist.playlist_tracks.order(position: :asc).pluck(:track_id)
    session.update(
      playlist: track_ids,
      playlist_shuffled: track_ids.shuffle,
      playlist_id: playlist.id,
      playlist_name: playlist.name,
      playlist_slug: playlist.slug,
      playlist_user_id: playlist.user.id,
      playlist_username: playlist.user.username
    )
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

  def init_session_playlist
    session[:playlist] ||= []
    session[:playlist_shuffled] ||= []
    session[:playlist_id] ||= 0
    session[:playlist_name] ||= ''
    session[:playlist_slug] ||= ''
    session[:playlist_user_id] ||= ''
    session[:playlist_username] ||= ''
    session[:loop] ||= false
    session[:shuffle] ||= false
  end
end
