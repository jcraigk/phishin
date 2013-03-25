class SearchController < ApplicationController

  def search
    date = params[:date]
    term = (params[:term] and params[:term].size >= 2 ? params[:term].downcase : nil)
    if date.present? or term.present?
      @results = true
      @total_results = 0
      if date.present?
        @total_results += 1 if @show = Show.where(date: params[:date]).includes(:venue).first
        @total_results += @other_shows.size if @other_shows = Show.where('extract(month from date) = ?', params[:date][5..6]).where('extract(day from date) = ?', params[:date][8..9]).where('date != ?', params[:date]).includes(:venue).order('date desc').all
      else
        if term.present?
          @songs = Song.where('lower(title) LIKE ?', "%#{term}%").order('title asc').all
          @venues = Venue.where('lower(name) LIKE ? OR lower(past_names) LIKE ? OR lower(city) LIKE ?', "%#{term}%", "%#{term}%", "%#{term}%").order('name asc').all
          # TODO Tours
          @tours = Tour.where('lower(name) LIKE ?', "%#{term}%").order('name asc').all
          @total_results = @songs.size + @venues.size + @tours.size
        end
      end
    else
      @results = false
    end
    render layout: false if request.xhr?
  end

end