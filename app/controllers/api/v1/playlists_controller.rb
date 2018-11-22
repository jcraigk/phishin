# frozen_string_literal: true
class Api::V1::PlaylistsController < Api::V1::ApiController
  caches_action :show, expires_in: CACHE_TTL

  def show
    return respond_with_404 unless playlist
    respond_with_success playlist
  end

  private

  def playlist
    @playlist ||=
      Playlist.where(id: params[:id])
              .or(Playlist.where(slug: params[:id]))
              .first
  end
end
