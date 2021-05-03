# frozen_string_literal: true
class Api::V1::TagsController < Api::V1::ApiController
  caches_action_params :index
  caches_action_params :show

  def index
    respond_with_success(get_data_for(Tag), serialize_method: :as_json)
  end

  def show
    respond_with_success Tag.friendly.find(params[:id])
  end
end
