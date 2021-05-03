# frozen_string_literal: true
class Api::V1::VenuesController < Api::V1::ApiController
  caches_action_params :index
  caches_action_params :show

  def index
    respond_with_success get_data_for(Venue)
  end

  def show
    respond_with_success Venue.friendly.find(params[:id])
  end
end
