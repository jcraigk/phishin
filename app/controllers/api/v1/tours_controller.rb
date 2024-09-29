class Api::V1::ToursController < Api::V1::ApiController
  caches_action_params :index
  caches_action_params :show

  def index
    respond_with_success get_data_for(tour_scope)
  end

  def show
    respond_with_success tour_scope.friendly.find(params[:id])
  end

  private

  def tour_scope
    Tour.includes(shows: :venue)
  end
end
