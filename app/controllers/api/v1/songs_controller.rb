# frozen_string_literal: true
class Api::V1::SongsController < Api::V1::ApiController
  caches_action :index, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :show, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL

  def index
    respond_with_success get_data_for(Song.relevant)
  end

  def show
    show = Song.where(id: params[:id])
               .or.where(slug: params[:id])
               .includes(tracks: :show)
               .first
    respond_with_success show
  end
end
