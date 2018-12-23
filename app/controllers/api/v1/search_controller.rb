# frozen_string_literal: true
class Api::V1::SearchController < Api::V1::ApiController
  def index
    return respond_with_invalid_term unless results
    respond_with_success results
  end

  private

  def results
    @results ||= SearchService.new(params[:term]).call
  end

  def respond_with_invalid_term
    render json: {
      success: false,
      message: I18n.t('search.term_too_short', min_length: MIN_SEARCH_TERM_LENGTH)
    }, status: 400
  end
end
