# frozen_string_literal: true
class SearchController < ApplicationController
  def results
    if params[:term].present?
      results = SearchService.new(params[:term]).call

      @show = results[:show] || nil
      @other_shows = results[:other_shows] || []
      @songs = results[:songs] || []
      @venues = results[:venues] || []
      @tours = results[:tours] || []

      @total_results = @other_shows.size + @songs.size + @venues.size + @tours.size
      @total_results += 1 if @show.present?
    end

    render layout: false if request.xhr?
  end
end
