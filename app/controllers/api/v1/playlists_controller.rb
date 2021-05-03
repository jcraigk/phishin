# frozen_string_literal: true
class Api::V1::PlaylistsController < Api::V1::ApiController
  caches_action_params :show, %i[id]

  def show
    return respond_with_404 unless playlist
    respond_with_success playlist
  end

  private

  def playlist
    @playlist ||=
      Playlist.where(id: params[:id])
              .or(Playlist.where(slug: params[:id]))
              .includes(:tracks)
              .first
  end
end
