# frozen_string_literal: true
class AmbiguousSlugController < ApplicationController
  include AmbiguousSlugs::Date
  include AmbiguousSlugs::DayOfYear
  include AmbiguousSlugs::Year
  include AmbiguousSlugs::YearRange
  include AmbiguousSlugs::SongTitle
  include AmbiguousSlugs::VenueName
  include AmbiguousSlugs::TourName

  caches_action :resolve, expires_in: CACHE_TTL

  def resolve
    unless slug_as_date ||
           slug_as_year ||
           slug_as_day_of_year ||
           slug_as_year_range ||
           slug_as_song ||
           slug_as_venue ||
           slug_as_tour
      return redirect_to(:root)
    end

    return redirect_to(@redirect) if @redirect
    request.xhr? ? render(@view, layout: false) : render(@view)
  end
end
