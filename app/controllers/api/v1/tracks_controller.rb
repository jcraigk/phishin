# frozen_string_literal: true
class Api::V1::TracksController < Api::V1::ApiController
  caches_action :index, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :show, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL

  def index
    rel = params[:tag] ? Track.tagged_with(params[:tag]) : track_scope
    respond_with_success get_data_for(rel)
  end

  def show
    respond_with_success Track.includes(:tags, :show).find_by!(id: params[:id])
  end

  private

  def track_scope
    Track.includes(:show, :songs, :tags)
  end
end
