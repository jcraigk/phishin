# frozen_string_literal: true
class MapController < ApplicationController
  def index
    params[:date_start] ||= '1983-01-01'
    params[:date_stop]  ||= Date.today.to_s
    render_xhr_without_layout
  end

  def search
    params[:date_start] ||= Show.order(date: :asc).first.date
    params[:date_stop] ||= Show.order(date: :desc).first.date
    if params[:lat].present? && params[:lng].present? && params[:distance].present?
      venues_with_shows = []
      venues = Venue.near([params[:lat], params[:lng]], params[:distance])
      venues.each do |venue|
        shows =
          Show.where(
            'venue_id = ? and date >= ? and date <= ?',
            venue.id,
            params[:date_start],
            params[:date_stop]
          ).order(date: :desc).all
        venue = venue.as_json
        if shows.any?
          venue[:shows] = shows.map(&:as_json)
          venues_with_shows << venue
        end
      end

      render json: { success: true, venues: venues_with_shows }
      return
    end

    render json: { success: false, msg: 'No results matched your criteria' }
  end
end
