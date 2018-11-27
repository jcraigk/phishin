# frozen_string_literal: true
class MapController < ApplicationController
  def index
    params[:date_start] ||= '1983-01-01'
    params[:date_stop]  ||= Date.today.to_s
    render_xhr_without_layout
  end

  def search
    init_date_params
    return render json: { success: true, venues: relevant_venues } if all_params_present?
    render json: { success: false, msg: 'No search criteria provided' }
  end

  private

  def all_params_present?
    params[:lat] && params[:lng] && params[:distance]
  end

  def init_date_params
    params[:date_start] ||= Show.order(date: :asc).first.date
    params[:date_stop] ||= Show.order(date: :desc).first.date
  end

  def relevant_venues
    venues.each_with_object([]) do |venue, relevant_venues|
      shows = relevant_shows_for(venue)
      next unless shows.any?
      relevant_venues << venue.as_json.merge(shows: shows.map(&:as_json))
    end
  end

  def venues
    @venues ||= Venue.near([params[:lat], params[:lng]], params[:distance]).includes(:shows)
  end

  def relevant_shows_for(venue)
    venue.shows.select do |show|
      show.date >= Time.parse(params[:date_start]) && show.date <= Time.parse(params[:date_stop])
    end.sort_by(&:date).reverse
  end
end
