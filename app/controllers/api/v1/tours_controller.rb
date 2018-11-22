# frozen_string_literal: true
class Api::V1::ToursController < Api::V1::ApiController
  caches_action :index, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL
  caches_action :show, cache_path: proc { |c| c.params }, expires_in: CACHE_TTL

  def index
    respond_with_success get_data_for(Tour)
  end

  def show
    respond_with_success Tour.includes(:shows).friendly.find(params[:id])
  end
end
