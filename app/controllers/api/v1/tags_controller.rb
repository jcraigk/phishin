# frozen_string_literal: true
class Api::V1::TagsController < Api::V1::ApiController
  caches_action :index, expires_in: CACHE_TTL
  caches_action :show, expires_in: CACHE_TTL

  def index
    respond_with_success(get_data_for(Tag), serialize_method: :as_json)
  end

  def show
    respond_with_success Tag.friendly.find(params[:id])
  end
end
