# frozen_string_literal: true
class SearchController < ApplicationController
  def results
    perform_search
    render_xhr_without_layout
  end

  private

  def perform_search
    params[:term] = params[:term]&.strip || ''
    return error unless search_results
    search_results.each { |k, v| instance_variable_set("@#{k}", v) }
    @any_results = search_results.values.find(&:present?)
  end

  def search_results
    @search_results ||= SearchService.new(params[:term]).call
  end

  def error
    @error = I18n.t('search.term_too_short', min_length: MIN_SEARCH_TERM_LENGTH)
  end
end
