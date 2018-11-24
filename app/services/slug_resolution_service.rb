# frozen_string_literal: true
class SlugResolutionService
  attr_reader :slug, :arg

  def initialize(slug)
    @slug = slug
  end

  def call
    if slug_is_day_of_year? # `10-31`, `octobor-31`
      SlugShowsOnDayOfYearService.new(*arg).call
    elsif slug_is_year? # `1997`
      SlugShowsDuringYearService.new(arg).call
    elsif slug_is_year_range? # `1997-2000`
      SlugShowsDuringYearRangeService.new(*arg).call
    elsif slug_is_date? # `1995-10-31`
      SlugShowService.new(slug).call
    elsif slug_is_song?
      SlugSongService.new(arg).call
    elsif slug_is_venue?
      SlugVenueService.new(arg).call
    elsif slug_is_tour?
      SlugTourService.new(arg).call
    else
      [nil, {}, root_path]
    end
  end

  private

  def slug_is_day_of_year?
    return false unless slug =~
      /\A(january|february|march|april|may|june|july|august|september|october|november|december)-(\d{1,2})\z/i
    @arg = [Regexp.last_match[1], Regexp.last_match[2]]
    true
  end

  def slug_is_year?
    return false unless slug =~ /\A\d{4}\z/
    @arg = Regexp.last_match[1]
    true
  end

  def slug_is_year_range?
    return false unless slug =~ /\A(\d{4})-(\d{4})\z/
    @arg = [Regexp.last_match[1].titleize, Integer(Regexp.last_match[2], 10)]
    true
  end

  def slug_is_date?
    slug =~ /\A\d{4}(\-|\.)\d{1,2}(\-|\.)\d{1,2}\z/
  end

  def slug_is_song?
    @arg = Song.find_by(slug: slug)
  end

  def slug_is_venue?
    @arg = Venue.find_by(slug: slug)
  end

  def slug_is_tour?
    @arg = Tour.find_by(slug: slug)
  end
end
