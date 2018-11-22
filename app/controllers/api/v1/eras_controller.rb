# frozen_string_literal: true
class Api::V1::ErasController < Api::V1::ApiController
  caches_action :index, expires_in: CACHE_TTL
  caches_action :show, expires_in: CACHE_TTL

  def index
    respond_with_success(ERAS)
  end

  def show
    return respond_with_success(ERAS["#{params[:id]}.0"]) if params[:id].to_i.in?([1, 2, 3])
    respond_with_404
  end
end
