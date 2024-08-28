class AmbiguityController < ApplicationController
  include Ambiguity::Date
  include Ambiguity::DayOfYear
  include Ambiguity::Year
  include Ambiguity::YearRange
  include Ambiguity::SongTitle
  include Ambiguity::VenueName
  include Ambiguity::TourName

  caches_action_params :resolve, %i[sort slug]

  def resolve
    if slug_matches_entity?
      @canonical_url = "#{App.base_url}/#{current_slug}"
      return redirect_to(@redirect) if @redirect
      return render_view(@view)
    end

    redirect_to :root
  end

  private

  def apply_shows_tag_filter
    @all_shows = @shows
    return if params[:tag_slug].blank? || params[:tag_slug] == "all"
    @shows = @shows.tagged_with(params[:tag_slug])
  end

  def validate_sorting_for_tracks
    params[:sort] = "shows.date desc" unless
      params[:sort].in?([ "title", "shows.date desc", "shows.date asc", "likes", "duration" ])
    order_by_for_tracks
  end

  def order_by_for_tracks # rubocop:disable Metrics/MethodLength
    @order_by =
      case params[:sort]
      when "title"
        { title: :asc }
      when "shows.date asc", "shows.date desc"
        params[:sort]
      when "likes"
        { likes_count: :desc }
      when "duration"
        { duration: :desc }
      end
  end

  def validate_sorting_for_shows
    params[:sort] = "date desc" unless
      params[:sort].in?([ "date desc", "date asc", "likes", "duration" ])
    order_by_for_shows
  end

  def order_by_for_shows
    @order_by =
      if params[:sort].in?([ "date asc", "date desc" ])
        params[:sort]
      elsif params[:sort] == "likes"
        { likes_count: :desc, date: :desc }
      elsif params[:sort] == "duration"
        "shows.duration desc, date desc"
      end
  end

  def current_slug
    params[:slug]
  end

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
