# frozen_string_literal: true
class SearchController < ApplicationController
  def results
    assign_vars_from_results
    calculate_totals
    render_xhr_without_layout
  end

  private

  def raw_results
    @raw_results ||= SearchService.new(params[:term]).call
  end

  def assign_vars_from_results
    %i[exact_show other_shows songs venues tours].each do |var_name|
      instance_variable_set("@#{var_name}", raw_results[var_name])
    end
  end

  def calculate_totals
    @total_results = @other_shows.size + @songs.size + @venues.size + @tours.size
    @total_results += 1 if @show.present?
  end
end
