class Api::V1::ErasController < Api::V1::ApiController
  caches_action_params :index
  caches_action_params :show, %i[id]

  def index
    respond_with_success(ERAS)
  end

  def show
    return respond_with_success(ERAS["#{params[:id]}.0"]) if params[:id].to_i.in?([1, 2, 3])
    respond_with_not_found
  end
end
