# frozen_string_literal: true
class Api::V1::SearchController < Api::V1::ApiController
  def index
    term = params[:term]
    if term.present?
      respond_with_success search(term)
    else
      respond_with_failure('Enter a term')
    end
  end

  private

  #todo this duplicates functionality of search_controller...should be refactored into concern
  def search(term)
    term.downcase!
    if is_date? term
      date = parse_date term
      total_results = 0
      show = Show.avail.where(date: date).includes(:venue).first
      other_shows = Show.avail.where('extract(month from date) = ?', date[5..6]).where('extract(day from date) = ?', date[8..9]).where('date != ?', date).includes(:venue).order('date desc').all
    else
      songs = Song.relevant.where('lower(title) LIKE ?', "%#{term}%").order('title asc').all
      venues = Venue.relevant.where('lower(name) LIKE ? OR lower(abbrev) LIKE ? OR lower(past_names) LIKE ? OR lower(city) LIKE ? OR lower(state) LIKE ? OR lower(country) LIKE ?', "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%").order('name asc').all
      tours = Tour.where('lower(name) LIKE ?', "%#{term}%").order('name asc').all
    end
    ret = {
      show: show,
      other_shows: other_shows,
      songs: songs,
      venues: venues,
      tours: tours
    }
  end

  def is_date?(str)
    if str =~ /^(\d{1,2})(\-|\/)(\d{1,2})(\-|\/)(\d{1,4})$/ or str =~ /^(\d{4})(\-|\/)(\d{1,2})(\-|\/)(\d{1,2})$/
      begin
        Date.parse str
        return true
      rescue
        return false
      end
    else
      return false
    end
  end

  def parse_date(str)
    # handle 2-digit year as in 3/11/90
    if str =~ /^(\d{1,2})(\-|\/)(\d{1,2})(\-|\/)(\d{1,2})$/
      zero = ($5.size == 1 ? '0' : '')
      year = ($5.to_i > 70 ? "19#{zero}#{$5}" : "20#{zero}#{$5}")
      str = "#{year}-#{$1}-#{$3}"
    end
    Date.parse(str).strftime("%Y-%m-%d")
  end
end
