# frozen_string_literal: true
class Api::V1::SearchController < Api::V1::ApiController
  def index
    return respond_with_invalid_term unless valid_search_term?
    respond_with_success SearchService.new(params[:term]).call
  end

  private

  def valid_search_term?
    params[:term]&.size.to_i >= MIN_SEARCH_TERM_SIZE
  end

  def respond_with_invalid_term
    render json: {
      success: false,
      message: "Search term must be at least #{MIN_SEARCH_TERM_SIZE} characters long"
    }, status: 400
  end
end
