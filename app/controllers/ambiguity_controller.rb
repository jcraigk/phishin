# frozen_string_literal: true
class AmbiguityController < ApplicationController
  include Ambiguity::Date
  include Ambiguity::DayOfYear
  include Ambiguity::Year
  include Ambiguity::YearRange
  include Ambiguity::SongTitle
  include Ambiguity::VenueName
  include Ambiguity::TourName

  caches_action :resolve, expires_in: CACHE_TTL

  def resolve
    if slug_matches_entity?
      return redirect_to(@redirect) if @redirect
      return request.xhr? ? render(@view, layout: false) : render(@view)
    end

    redirect_to :root
  end

  private

  def slug_matches_entity?
    slug_matches_timeframe? || slug_matches_object?
  end

  def slug_matches_timeframe?
    slug_as_date ||
      slug_as_year ||
      slug_as_day_of_year ||
      slug_as_year_range
  end

  def slug_matches_object?
    slug_as_song ||
      slug_as_venue ||
      slug_as_tour
  end
end
