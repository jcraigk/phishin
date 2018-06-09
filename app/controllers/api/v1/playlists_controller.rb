# frozen_string_literal: true
class Api::V1::PlaylistsController < ApiController
  before_action :authenticate_user_from_token!, except: [:show]

  caches_action :show, expires_in: CACHE_TTL
  caches_action :details, expires_in: CACHE_TTL

  def show
    playlist = Playlist.where(slug: params[:id]).first
    respond_with_success playlist
  end

  def details
    playlist = Playlist.where(id: params[:id].to_i).first
    playlist = Playlist.where(slug: params[:slug]).first unless playlist
    if playlist
      respond_with_success(playlist.as_json_api)
    else
      respond_with_failure('Playlist not found')
    end
  end

  def user_playlists
    playlists = Playlist.where(user_id: current_user.id).all
    respond_with_success playlists.map(&:as_json_api_basic)
  end

  def user_bookmarks
    bookmarks = PlaylistBookmark.where(user_id: current_user.id).all
    render json: { success: true, playlist_ids: bookmarks.map(&:playlist_id) }
  end

  # Bookmark a playlist
  # Requires :id
  def bookmark
    if bookmark = PlaylistBookmark.where(playlist_id: params[:id], user_id: current_user.id).first
      respond_with_failure 'Playlist already bookmarked'
    elsif playlist = Playlist.where(id: params[:id]).first
      PlaylistBookmark.create(playlist_id: params[:id], user_id: current_user.id)
      respond_with_success_simple 'Playlist bookmarked'
    else
      respond_with_failure 'Invalid request'
    end
  end

  # Unbookmark a playlist
  # Requires :id
  def unbookmark
    if bookmark = PlaylistBookmark.where(playlist_id: params[:id], user_id: current_user.id).first
      bookmark.destroy
      respond_with_success_simple 'Playlist unbookmarked'
    else
      respond_with_failure 'Playlist not bookmarked'
    end
  end

  # Create/update custom playlist
  # Requires :name, :slug, :track_ids (:id if updating)
  def save
    begin
      #todo Could we do the following with AR validations more cleanly?
      if params[:track_ids].size < 2
        respond_with_failure 'Saved playlists must contain at least 2 tracks'
      elsif !params[:name].present? or !params[:slug].present?
        respond_with_failure 'You must provide a name and URL for this playlist'
      elsif !params[:name].match(/^.{5,50}$/)
        respond_with_failure 'Name must be between 5 and 50 characters'
      elsif !params[:slug].match(/^[a-z0-9\-]{5,50}$/)
        respond_with_failure 'URL must be between 5 and 50 lowercase letters, numbers, or dashes'
      elsif params[:id].present?
        if playlist = Playlist.where(user_id: current_user.id, id: params[:id]).first
          playlist.update_attributes(name: params[:name], slug: params[:slug])
          playlist.playlist_tracks.map(&:destroy)
          create_playlist_tracks(playlist)
          respond_with_success_simple
        else
          respond_with_failure 'Playlist not found or not owned by user'
        end
      elsif Playlist.where(user_id: current_user.id).all.size >= MAX_PLAYLISTS_PER_USER
        respond_with_failure "Each user is limited to #{MAX_PLAYLISTS_PER_USER} playlists"
      elsif Playlist.where(name: params[:name], user_id: current_user.id).first
        respond_with_failure 'That name has already been taken; choose another'
      elsif Playlist.where(slug: params[:slug]).first
        respond_with_failure 'That slug has already been taken; choose another'
      else
        playlist = Playlist.create(user_id: current_user.id, name: params[:name], slug: params[:slug])
        create_playlist_tracks(playlist)
        render json: { success: true, playlist_id: playlist.id }
      end
    rescue
      respond_with_failure 'Invalid request'
    end
  end

  # Destroy custom playlist
  # Requires :id
  def destroy
    if playlist = Playlist.where(id: params[:id], user_id: current_user.id).first
      playlist.destroy
      respond_with_success_simple 'Playlist destroyed'
    else
      respond_with_failure 'Playlist not found or not owned by current user'
    end
  end

  private

  def create_playlist_tracks(playlist)
    params[:track_ids].take(100).each_with_index do |track_id, idx|
      PlaylistTrack.create(playlist_id: playlist.id, track_id: track_id, position: idx+1)
    end
    playlist.update_attributes(duration: playlist.tracks.map(&:duration).inject(0, &:+))
  end
end
