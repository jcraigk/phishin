class SearchController < ApplicationController
  def results
    perform_search
    render_view
  end

  private

  def perform_search
    params[:term] = params[:term]&.strip || ""
    return error unless search_results
    search_results.each { |k, v| instance_variable_set(:"@#{k}", v) }
    @any_results = search_results.values.find(&:present?)
  end

  def search_results
    @search_results ||= SearchService.new(params[:term]).call
  end

  def error
    @error = I18n.t("search.term_too_short", min_length: App.min_search_term_length)
  end
end
