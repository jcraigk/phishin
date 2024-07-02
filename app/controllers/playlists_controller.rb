class PlaylistsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_user!, only: %i[save destroy bookmark unbookmark]

  def active
    if (playlist = Playlist.find_by(slug: params[:slug]))
      activate_stored(playlist)
    end

    track_ids = session[:track_ids]
    tracks_by_id = Track.where(id: track_ids).includes(:show, track_tags: :tag).index_by(&:id)
    @tracks = track_ids&.map { |id| tracks_by_id[id] } || []
    @tracks_likes = user_likes_for_tracks(@tracks)
    @duration = @tracks&.sum(&:duration)
    @stored = Playlist.where(user: current_user).order(name: :asc) if current_user
    @ogp_audio_url = @tracks.first&.mp3_url

    render layout: false if request.xhr?
  end

  def stored
    @playlists = []

    if current_user
      bookmarked_ids = PlaylistBookmark.where(user: current_user).map(&:playlist_id)
      rel =
        case params[:filter]
        when 'phriends' then Playlist.where(id: bookmarked_ids)
        when 'mine' then Playlist.where(user: current_user)
        else Playlist.where('user_id = ? OR id IN (?)', current_user.id, bookmarked_ids)
        end
      @playlists = rel.includes(:user).order(order_by_for_stored_playlists).page(params[:page])
    end

    render layout: false if request.xhr?
  end

  def save
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

  def load
    render json: { playlist: session[:track_ids] }
  end

  def destroy
    if (playlist = current_user&.playlists&.find_by(id: params[:id]))
      playlist.destroy
      return render json: { success: true, msg: 'Playlist deleted' }
    end
    render json: { success: false, msg: 'Invalid playlist delete request' }
  end

  def bookmark
    if current_user && params[:id].present?
      if PlaylistBookmark.find_by(playlist_id: params[:id], user: current_user).present?
        return render json: { success: false, msg: 'Playlist already bookmarked' }
      end

      PlaylistBookmark.create(playlist_id: params[:id], user: current_user)
      return render json: { success: true, msg: 'Playlist bookmarked' }
    end

    render json: { success: false, msg: "Error fetching ID #{params[:id]}" }
  end

  def unbookmark
    if current_user &&
       params[:id] &&
       (bookmark = PlaylistBookmark.find_by(playlist_id: params[:id], user: current_user))
      bookmark.destroy
      return render json: { success: true, msg: 'Playlist unbookmarked' }
    end

    render json: { success: false, msg: 'Playlist not bookmarked' }
  end

  # Replace active playlist using one of:
  # (1) track_id
  # (2) date/slug combo from URL path (`/YYYY-MM-DD/:track_slug`)
  # (3) playlist by slug from URL path (`/play/:playlist_slug`)
  # (3) random show
  def enqueue_tracks
    reset_session
    path1, slug = params[:path]&.split('/')&.reject(&:empty?)
    return enqueue_playlist(slug) if path1 == 'play'
    show = enqueuable_show(path1)
    session[:track_ids] = show&.tracks&.order(position: :asc)&.pluck(:id) || []
    track_id = slug.present? ? show&.tracks&.find_by(slug:)&.id : params[:track_id]
    track_id ||= session[:track_ids].first
    render json: {
      success: true,
      url: @url,
      track_id:,
      msg: @msg
    }
  end

  def clear
    reset_session
    render json: { success: true, playlist: [] }
  end

  def reposition
    session[:track_ids] = params[:track_ids]&.map(&:to_i)&.take(100) || []
    render json: { success: true }
  end

  def add_track
    if session[:track_ids]&.include?(params[:track_id].to_i)
      return render json: { success: false, msg: 'Track already in playlist' }
    end

    if session[:track_ids].present? && session[:track_ids].size > 99
      msg = "Playlists are limited to #{Playlist::MAX_TRACKS} tracks"
      render json: { success: false, msg: }
    elsif (track = Track.find(params[:track_id]))
      session[:track_ids] ||= []
      session[:track_ids] << track.id
      render json: { success: true }
    else
      render json: { success: false, msg: 'Invalid track provided for playlist' }
    end
  end

  def remove_track
    track_id = params[:track_id].to_i
    if session[:track_ids]&.include?(track_id)
      session[:track_ids].delete(track_id)
      render json: { success: true }
    else
      render json: { success: false, msg: 'Track not in playlist' }
    end
  end

  def add_show
    if (show = Show.published.find_by(id: params[:show_id]))
      session[:track_ids] ||= []
      session[:track_ids] += show.tracks.sort_by(&:position).map(&:id)
      session[:track_ids] = session[:track_ids].uniq.take(Playlist::MAX_TRACKS)
      render json: { success: true, msg: 'Tracks from show added to playlist' }
    else
      render json: { success: false, msg: 'Invalid show provided for playlist' }
    end
  end

  def next_track_id
    return no_active_playlist if session[:track_ids].blank?
    track_ids = session[:track_ids]
    if track_ids.last == params[:track_id].to_i
      render json: { success: false, msg: 'End of playlist' }
    elsif (idx = track_ids.find_index(params[:track_id].to_i))
      render json: { success: true, track_id: track_ids[idx + 1] }
    else
      render json: { success: false, msg: 'track_id not in playlist' }
    end
  end

  def previous_track_id
    return no_active_playlist if session[:track_ids].none?
    track_ids = session[:track_ids]
    if track_ids.first == params[:track_id].to_i
      render json: { success: false, msg: 'Beginning of playlist' }
    elsif (idx = track_ids.find_index(params[:track_id].to_i))
      render json: { success: true, track_id: track_ids[idx - 1] }
    else
      render json: { success: false, msg: 'track_id not in playlist' }
    end
  end

  def random_song_track
    if (song = Song.find_by(id: params[:song_id]))
      track = song.tracks.sample
      show = Show.published.find_by(id: track.show_id)
      render json: { success: true, url: "/#{show.date}/#{track.slug}", track_id: track.id }
    else
      render json: { success: false, msg: 'Invalid song_id' }
    end
  end

  private

  def enqueuable_show(path_segment)
    if params[:track_id].present?
      Track.includes(:show).find(params[:track_id]).show
    elsif path_segment&.match?(/^\d{4}-\d{2}-\d{2}$/)
      Show.published.find_by(date: path_segment)
    else
      show = Show.published.random.first
      @url = "/#{show.date}"
      @msg = 'Playing random show...'
      show
    end
  end

  def enqueue_playlist(slug)
    session[:track_ids] =
      Playlist.find_by(slug:)
              &.playlist_tracks
              &.order(position: :asc)
              &.pluck(:track_id) || []
    render json: {
      success: true,
      track_id: session[:track_ids].first
    }
  end

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
    activate_stored(playlist)
  end

  def order_by_for_stored_playlists
    params[:sort] = 'name' unless params[:sort].in?(%w[name duration])
    "#{params[:sort]} asc"
  end

  def create_playlist_tracks(playlist)
    session[:track_ids]&.each_with_index do |track_id, idx|
      PlaylistTrack.create(playlist:, track_id:, position: idx + 1)
    end
    playlist.update(duration: playlist.tracks.sum(&:duration))
  end

  def activate_stored(playlist)
    update_playlist(playlist)
    retrieve_bookmark(playlist) if current_user
  end

  def update_playlist(playlist)
    session[:track_ids] = playlist.playlist_tracks.order(position: :asc).pluck(:track_id)
    session.merge!(playlist_attrs(playlist))
  end

  def playlist_attrs(playlist)
    {
      playlist_id: playlist.id,
      playlist_name: playlist.name,
      playlist_slug: playlist.slug,
      playlist_user_id: playlist.user.id,
      playlist_username: playlist.user.username
    }
  end

  def no_active_playlist
    render json: { success: false, msg: 'No active playlist' }
  end

  def retrieve_bookmark(playlist)
    bookmark = PlaylistBookmark.find_by(playlist_id: playlist.id, user: current_user)
    session[:playlist_bookmarked] = bookmark.present?
  end
end
