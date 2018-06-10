# frozen_string_literal: true
class Api::V1::TracksController < Api::V1::ApiController
  caches_action :index, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :show, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL

  def index
    tracks = Track.scoped
    tracks = tracks.tagged_with(params[:tag]) if params[:tag]
    respond_with_success get_data_for(tracks)
  end

  def show
    respond_with_success Track.where(id: params[:id]).includes(:tags).first
  end
end
