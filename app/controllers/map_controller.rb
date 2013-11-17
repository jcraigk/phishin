class MapController < ApplicationController

  def search
    params[:date_start] ||= Show.order('date asc').first.date
    params[:date_stop] ||= Show.order('date desc').first.date
    if params[:lat].present? and params[:lng].present? and params[:distance].present?
      venues_with_shows = []
      venues = Venue.near([params[:lat], params[:lng]], params[:distance])
      for venue in venues
        shows = Show.where('venue_id = ? and date >= ? and date <= ?', venue.id, params[:date_start], params[:date_stop]).order(:date).all
        venue = venue.as_json
        if shows.size > 0
          venue[:shows] = shows.map(&:as_json)
          venues_with_shows << venue
        end
      end      
      render json: {success: true, venues: venues_with_shows}
    else
      render json: { success: false, msg: 'No results matched your criteria'}
    end
  end

end