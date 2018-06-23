# frozen_string_literal: true
class Api::V1::PlaylistsController < Api::V1::ApiController
  before_action :authenticate_user_from_token!, except: [:show]

  caches_action :show, expires_in: CACHE_TTL
  caches_action :details, expires_in: CACHE_TTL

  def show
    respond_with_success playlist
  end

  def details
    return respond_with_success(playlist.as_json_api) if playlist
    respond_with_failure 'Playlist not found'
  end

  def user_playlists
    respond_with_success this_user_playlists.map(&:as_json_api_basic)
  end

  def user_bookmarks
    render json: {
      success: true,
      playlist_ids: this_user_bookmarks.map(&:playlist_id)
    }
  end

  # Bookmark a playlist
  # Requires :id
  def bookmark
    if user_bookmark.present?
      respond_with_failure 'Playlist already bookmarked'
    elsif playlist.present?
      PlaylistBookmark.create(
        playlist_id: params[:id],
        user: current_user
      )
      respond_with_success_simple 'Playlist bookmarked'
    else
      respond_with_failure 'Invalid request'
    end
  end

  # Unbookmark a playlist
  # Requires :id
  def unbookmark
    if user_bookmark.present?
      bookmark.destroy
      return respond_with_success_simple 'Playlist unbookmarked'
    end

    respond_with_failure 'Playlist not bookmarked'
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
      elsif !params[:name].match(/\A.{5,50}\z/)
        respond_with_failure 'Name must be between 5 and 50 characters'
      elsif !params[:slug].match(/\A[a-z0-9\-]{5,50}\z/)
        respond_with_failure 'URL must be between 5 and 50 lowercase letters, numbers, or dashes'
      elsif params[:id].present?
        if playlist = Playlist.where(user: current_user, id: params[:id]).first
          playlist.update_attributes(name: params[:name], slug: params[:slug])
          playlist.playlist_tracks.map(&:destroy)
          create_playlist_tracks(playlist)
          respond_with_success_simple
        else
          respond_with_failure 'Playlist not found or not owned by user'
        end
      elsif Playlist.where(user: current_user).count >= MAX_PLAYLISTS_PER_USER
        respond_with_failure "Each user is limited to #{MAX_PLAYLISTS_PER_USER} playlists"
      elsif Playlist.where(name: params[:name], user: current_user).first
        respond_with_failure 'That name has already been taken; choose another'
      elsif Playlist.where(slug: params[:slug]).first
        respond_with_failure 'That slug has already been taken; choose another'
      else
        playlist = Playlist.create(user: current_user, name: params[:name], slug: params[:slug])
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
    if playlist.present?
      playlist.destroy
      return respond_with_success_simple 'Playlist destroyed'
    end

    respond_with_failure 'Playlist not found'
  end

  private

  def playlist
    @playlist ||=
      Playlist.where(id: params[:id])
              .or(Playlist.where(slug: params[:id]))
              .first
  end

  def this_user_playlists
    @user_playlists ||= Playlist.where(user: current_user)
  end

  def this_user_bookmarks
    @user_bookmarks ||= PlaylistBookmark.where(user: current_user)
  end

  def user_bookmark
    @user_bookmark ||=
      PlaylistBookmark.where(
        playlist_id: params[:id],
        user: current_user
      ).first
  end

  def create_playlist_tracks(playlist)
    params[:track_ids]
      .take(100)
      .each_with_index do |track_id, idx|
        PlaylistTrack.create(
          playlist_id: playlist.id,
          track_id: track_id,
          position: idx + 1
        )
      end

    playlist.update(duration: playlist_duration(playlist))
  end

  def playlist_duration(playlist)
    playlist.tracks.map(&:duration).inject(0, &:+)
  end
end
