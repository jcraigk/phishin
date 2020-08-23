# frozen_string_literal: true
class Api::V1::SongsController < Api::V1::ApiController
  caches_action :index, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :show, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL

  def index
    respond_with_success get_data_for(Song), serialize_method: :as_json
  end

  def show
    respond_with_success song_scope.friendly.find(params[:id])
  end

  private

  def song_scope
    scope = Song.includes(tracks: %i[show songs tags])
    if params[:sort_attr] == 'duration'
      order = params[:sort_dir].downcase.in?(%w[asc desc]) ? params[:sort_dir] : 'asc'
      scope = scope.order("tracks.duration #{order}")
    end
    scope
  end
end
