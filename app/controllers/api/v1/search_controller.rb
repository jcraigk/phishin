class Api::V1::SearchController < Api::V1::ApiController
  def index
    return respond_with_invalid_term unless results
    respond_with_success results
  end

  private

  def results
    @results ||= SearchService.call(term: params[:term], scope: "all", audio_status: "complete_or_partial")&.except(:tours)
  end

  def respond_with_invalid_term
    render json: {
      success: false,
      message: I18n.t("search.term_too_short", min_length: App.min_search_term_length)
    }, status: :bad_request
  end
end
