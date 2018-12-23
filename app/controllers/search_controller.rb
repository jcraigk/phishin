# frozen_string_literal: true
class SearchController < ApplicationController
  def results
    perform_search
    render_xhr_without_layout
  end

  private

  def perform_search
    return @error = 'Search term must be at least 3 characters long' if search_term_too_short?
    results = SearchService.new(params[:term]).call
    results.each { |k, v| instance_variable_set("@#{k}", v) }
    @any_results = results.values.find(&:present?)
  end

  def search_term_too_short?
    params[:term]&.size.to_i < MIN_SEARCH_TERM_SIZE
  end
end
