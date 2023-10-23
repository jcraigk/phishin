class PlaylistsController < ApplicationController
  EMPTY_PLAYLIST = {
    tracks: [],
    shuffled_tracks: [],
    id: 0,
    name: '',
    slug: '',
    user_id: 0,
    username: '',
    loop: false,
    shuffle: false
  }.freeze

  skip_before_action :verify_authenticity_token
  before_action :init_session
  before_action :authenticate_user!, only: %i[save destroy bookmark unbookmark]

  def active
    if (playlist = Playlist.find_by(slug: params[:slug]))
      activate_stored(playlist)
    end

    track_ids = session['playlist']['tracks']
    tracks_by_id = Track.where(id: track_ids).includes(:show, track_tags: :tag).index_by(&:id)
    @tracks = track_ids&.map { |id| tracks_by_id[id] } || []
    @tracks_likes = user_likes_for_tracks(@tracks)
    @duration = @tracks&.sum(&:duration)
    @stored = Playlist.where(user: current_user).order(name: :asc) if current_user

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
    render json: { playlist: session['playlist']['tracks'] }
  end

  def destroy
    if current_user && params[:id] && (playlist = fetch_playlist)
      playlist.destroy
      return render json: { success: true, msg: 'Playlist deleted' }
    end

    render json: { success: false, msg: 'Invalid delete request' }
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

  # Force an entire show into the playlist based on a track from the show
  def override
    clear_session

    session['playlist']['tracks'] =
      Track.includes(:show).find_by(id: params[:track_id]).show.tracks.order(:position).pluck(:id)
    shuffle_tracks

    render json: { success: true, playlist: session['playlist']['tracks'] }
  end

  def clear
    clear_session
    render json: { success: true, playlist: [] }
  end

  def reposition
    session['playlist']['tracks'] = params[:track_ids]&.map(&:to_i)&.take(100) || []
    shuffle_tracks
    render json: { success: true }
  end

  def add_track
    return if (tracks = session['playlist']['tracks']).nil?

    if tracks.include?(params[:track_id].to_i)
      return render json: { success: false, msg: 'Track already in playlist' }
    end

    if tracks.size > 99
      msg = "Playlists are limited to #{Playlist::MAX_TRACKS} tracks"
      render json: { success: false, msg: }
    elsif (track = Track.find(params[:track_id]))
      session['playlist']['tracks'] << track.id
      num_tracks = session['playlist']['tracks'].size
      session['playlist']['shuffled_tracks'].insert(rand(0..num_tracks), track.id)
      render json: { success: true }
    else
      render json: { success: false, msg: 'Invalid track provided for playlist' }
    end
  end

  def add_show
    if (show = Show.published.find_by(id: params[:show_id]))
      session['playlist']['tracks'] += show.tracks.sort_by(&:position).map(&:id)
      session['playlist']['tracks'] = session['playlist']['tracks'].uniq.take(Playlist::MAX_TRACKS)
      render json: { success: true, msg: 'Tracks from show added to playlist' }
    else
      render json: { success: false, msg: 'Invalid show provided for playlist' }
    end
  end

  def next_track_id
    if params['playlist'].present?
      session['playlist']['tracks'] = params['playlist'].split(',').map(&:to_i)
    end

    if session['playlist']['tracks'].blank?
      return render json: { success: false, msg: 'No active playlist' }
    end

    prefix = session['playlist']['shuffle'] ? 'shuffled_' : nil
    track_ids = session['playlist']["#{prefix}tracks"]

    if track_ids.last == params[:track_id].to_i
      if session['playlist']['loop']
        render json: { success: true, track_id: track_ids.first }
      else
        render json: { success: false, msg: 'End of playlist' }
      end
    elsif (idx = track_ids.find_index(params[:track_id].to_i))
      render json: { success: true, track_id: track_ids[idx + 1] }
    else
      render json: { success: false, msg: 'track_id not in playlist' }
    end
  end

  def previous_track_id
    if params['playlist'].present?
      session['playlist']['tracks'] = params['playlist'].split(',').map(&:to_i)
    end

    if session['playlist']['tracks'].none?
      return render json: { success: false, msg: 'No active playlist' }
    end

    prefix = session['playlist']['shuffle'] ? 'shuffled_' : nil
    track_ids = session['playlist']["#{prefix}tracks"]

    if track_ids.first == params[:track_id].to_i
      if session['loop']
        render json: { success: true, track_id: track_ids.last }
      else
        render json: { success: false, msg: 'Beginning of playlist' }
      end
    elsif (idx = track_ids.find_index(params[:track_id].to_i))
      render json: { success: true, track_id: track_ids[idx - 1] }
    else
      render json: { success: false, msg: 'track_id not in playlist' }
    end
  end

  def submit_playback_loop
    if params['loop'] == 'true'
      session['loop'] = true
      msg = 'Playback looping enabled'
    else
      session['loop'] = false
      msg = 'Playback looping disabled'
    end

    render json: { success: true, msg: }
  end

  def submit_playback_shuffle
    if params['shuffle'] == 'true'
      session['shuffle'] = true
      msg = 'Playback shuffling enabled'
    else
      session['shuffle'] = false
      msg = 'Playback shuffling disabled'
    end
    render json: { success: true, msg: }
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
    if (song = Song.find_by(id: params[:song_id]))
      track = song.tracks.sample
      show = Show.published.find_by(id: track.show_id)
      render json: { success: true, url: "/#{show.date}", track_id: track.id }
    else
      render json: { success: false, msg: 'Invalid song_id' }
    end
  end

  private

  def fetch_playlist
    Playlist.find_by(id: params[:id], user: current_user)
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
    session['playlist']['tracks'].each_with_index do |track_id, idx|
      PlaylistTrack.create(playlist:, track_id:, position: idx + 1)
    end
    playlist.update(duration: playlist.tracks.sum(&:duration))
  end

  def activate_stored(playlist)
    update_playlist(playlist)
    retrieve_bookmark(playlist) if current_user
  end

  def update_playlist(playlist)
    track_ids = playlist.playlist_tracks.order(position: :asc).pluck(:track_id)
    session['playlist'].merge!(
      tracks: track_ids,
      shuffled_tracks: track_ids.shuffle,
      id: playlist.id,
      name: playlist.name,
      slug: playlist.slug,
      user_id: playlist.user.id,
      username: playlist.user.username
    )
  end

  def retrieve_bookmark(playlist)
    bookmark = PlaylistBookmark.find_by(playlist_id: playlist.id, user: current_user)
    session['playlist_is_bookmarked'] = bookmark.present?
  end

  def clear_session
    session.update(playlist: EMPTY_PLAYLIST.dup)
  end

  def init_session
    return if session['playlist'].is_a?(Hash) # Ease into new session format
    session['playlist'] = EMPTY_PLAYLIST.dup
    session['playlist'] = session['playlist'].with_indifferent_access
  end

  def shuffle_tracks
    session['playlist']['shuffled_tracks'] = session['playlist']['tracks'].shuffle
  end
end
