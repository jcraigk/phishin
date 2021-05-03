# frozen_string_literal: true
class Api::V1::SongsController < Api::V1::ApiController
  caches_action_params :index
  caches_action_params :show

  def index
    respond_with_success get_data_for(Song), serialize_method: :as_json
  end

  def show
    respond_with_success song_scope.friendly.find(params[:id])
  end

  private

  def song_scope
    scope = Song.includes(tracks: %i[show songs tags])
    dir = params[:sort_dir]&.downcase&.in?(%w[asc desc]) ? params[:sort_dir] : 'asc'
    order_col = params[:sort_attr] == 'duration' ? 'tracks.duration' : 'shows.date'
    scope.order("#{order_col} #{dir}")
  end
end
