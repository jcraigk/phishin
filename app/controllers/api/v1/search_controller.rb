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

  def where_search_str
    'lower(name) LIKE :term OR lower(abbrev) LIKE :term ' \
    'OR lower(past_names) LIKE :term OR lower(city) LIKE :term ' \
    'OR lower(state) LIKE :term OR lower(country) LIKE :term'
  end

  def search(term)
    term.downcase!
    if date?(term)
      date = parse_date(term)
      show = Show.avail.where(date: date).includes(:venue).first
      other_shows =
        Show.avail
            .on_day_of_year(date[5..6], date[8..9])
            .where('date != ?', date)
            .includes(:venue)
            .order('date desc')
    else
      songs =
        Song.relevant
            .where('title ILIKE ?', "%#{term}%")
            .order('title asc')
      venues =
        Venue.relevant
             .where(where_search_str, term: "%#{term}%")
             .order('name asc')
      tours =
        Tour.where('name ILIKE ?', "%#{term}%")
            .order('name asc')
    end
    {
      show: show,
      other_shows: other_shows,
      songs: songs,
      venues: venues,
      tours: tours
    }
  end

  def date?(str)
    return false unless
      str =~ %r{\A(\d{1,2})(\-|\/)(\d{1,2})(\-|\/)(\d{1,4})\z} ||
      str =~ %r{\A(\d{4})(\-|\/)(\d{1,2})(\-|\/)(\d{1,2})\z}

    begin
      Date.parse(str)
      true
    rescue ArgumentError
      false
    end
  end

  def parse_date(str)
    # Handle 2-digit year as in 3/11/90
    if %r{\A(\d{1,2})(\-|\/)(\d{1,2})(\-|\/)(\d{1,2})\z}.match?(str)
      zero = (year_match.size == 1 ? '0' : '')
      year =
        if year_match.to_i > 70
          "19#{zero}#{year_match}"
        else
          "20#{zero}#{year_match}"
        end
      str = "#{year}-#{month_match}-#{day_match}"
    end
    Date.parse(str).strftime('%Y-%m-%d')
  end

  def year_match
    Regexp.last_match[5]
  end

  def month_match
    Regexp.last_match[1]
  end

  def day_match
    Regexp.last_match[1]
  end
end
