# frozen_string_literal: true
class Api::V1::SearchController < Api::V1::ApiController
  def index
    respond_with_success SearchService.new(params[:term]).call
  end
end
