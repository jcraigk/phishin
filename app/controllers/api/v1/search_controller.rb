# frozen_string_literal: true
class Api::V1::SearchController < Api::V1::ApiController
  def index
    return respond_with_success(search_results) if params[:term].present?
    respond_with_failure('Enter a term')
  end

  private

  def search_results
    SearchService.new(params[:term]).call
  end
end
