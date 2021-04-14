# frozen_string_literal: true
class MapController < ApplicationController
  def index
    params[:date_start] ||= '1983-01-01'
    params[:date_stop]  ||= Time.zone.today.to_s
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
    params[:date_start] ||= Show.published.order(date: :asc).first.date
    params[:date_stop] ||= Show.published.order(date: :desc).first.date
  end

  def relevant_venues
    venues_nearby.each_with_object([]) do |venue, relevant_venues|
      shows = relevant_shows_for(venue)
      next unless shows.any?
      relevant_venues << venue.as_json.merge(shows: shows.map(&:as_json))
    end
  end

  def venues_nearby
    @venues_nearby ||= Venue.near([params[:lat], params[:lng]], params[:distance]).includes(:shows)
  end

  def relevant_shows_for(venue)
    venue.shows.select { |show| shows_in_timeframe(show) }.sort_by(&:date).reverse
  end

  def shows_in_timeframe(show)
    show.date >= Time.zone.parse(params[:date_start]) &&
      show.date <= Time.zone.parse(params[:date_stop])
  rescue ArgumentError
    true
  end
end
