# frozen_string_literal: true
class ContentController < ApplicationController
  caches_action :years, expires_in: CACHE_TTL
  caches_action :songs, expires_in: CACHE_TTL
  caches_action :venues, expires_in: CACHE_TTL
  # TODO: Should we cache ambiguous_slug here too?

  ###############################
  # Hard-coded actions
  ###############################

  def years
    @shows =
      ERAS.values.flatten.each_with_object({}) do |year, shows|
        shows[year] = shows_for_year(year)
      end
    render_xhr_without_layout
  end

  def songs
    @songs =
      Song.relevant
          .title_starting_with(char_param)
          .order(songs_order_by)
    render_xhr_without_layout
  end

  def venues
    @venues =
      Venue.relevant
           .name_starting_with(char_param)
           .order(venues_order_by)
    render_xhr_without_layout
  end

  def map
    params[:date_start] ||= '1983-01-01'
    params[:date_stop]  ||= Date.today.to_s
    render_xhr_without_layout
  end

  def top_liked_shows
    @shows =
      Show.avail
          .where('likes_count > 0')
          .includes(:venue, :tags)
          .order(likes_count: :desc, date: :desc)
          .limit(40)
    @shows_likes = @shows.map { |show| get_user_show_like(show) }
    render_xhr_without_layout
  end

  def top_liked_tracks
    @tracks =
      Track.where('likes_count > 0')
           .includes(:show, :tags)
           .order(likes_count: :desc, title: :asc)
           .limit(40)
    @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
    render_xhr_without_layout
  end

  def ambiguous_slug
    g = params[:slug]

    # Day of Year?
    monthday = g.match(
      /\A(january|february|march|april|may|june|july|august|september|october|november|december)-(\d{1,2})\z/i
    )
    if monthday.present?
      if day_of_year(Date::MONTHNAMES.index(monthday[1].titleize), Integer(monthday[2], 10))
        @title = "#{monthday[1].titleize} #{Integer(monthday[2], 10)}"
        view = :year_or_scope
      else
        view = :show_not_found
      end
    # Year?
    elsif /\A\d{4}\z/.match?(g)
      if year g
        @title = "Year: #{g}"
        @controller_action = 'year'
        view = :year_or_scope
      else
        redirect_to :root
      end
    # Year range?
    elsif g =~ /\A(\d{4})-(\d{4})\z/
      matches = Regexp.last_match
      if year_range(matches[1], matches[2])
        @title = "Years: #{matches[1]}-#{matches[2]}"
        view = :year_or_scope
        @controller_action = 'year_range'
      else
        redirect_to :root
      end
    # Show?
    elsif /\A\d{4}(\-|\.)\d{1,2}(\-|\.)\d{1,2}\z/.match?(g)
      view = show(g) ? :show : :show_not_found
      @controller_action = 'show'
    # Song?
    elsif song(g)
      view = :song
      @controller_action = 'song'
    # Venue?
    elsif venue(g)
      view = :venue
      @controller_action = 'venue'
    # Tour?
    elsif tour(g)
      @title = @tour.name
      view = :year_or_scope
    # Fall back to root
    else
      redirect_to(:root) && return
    end

    redirect_to(@redirect) && return if @redirect
    request.xhr? ? render(view, layout: false) : render(view)
  end

  private

  def shows_for_year(year)
    shows = Show.avail.includes(:venue)
    return shows.between_years('1983', '1987') if year == '1983-1987'
    shows.during_year(year)
  end

  def day_of_year(month, day)
    validate_sorting_for_year_or_scope
    @shows = Show.avail
                 .on_day_of_year(month, day)
                 .includes(:tour, :venue, :tags)
                 .order(@order_by)
    @sections = {}
    @shows.group_by(&:tour_name).each do |tour, show_list|
      @sections[tour] = {
        shows: show_list,
        likes: show_list.map { |s| get_user_show_like(s) }
      }
    end

    @shows.any?
  end

  def year(year)
    validate_sorting_for_year_or_scope
    @shows = Show.avail
                 .during_year(year)
                 .includes(:tour, :venue, :tags)
                 .order(@order_by)
    @sections = {}
    @shows.group_by(&:tour_name).each do |tour, show_list|
      @sections[tour] = {
        shows: show_list,
        likes: show_list.map { |s| get_user_show_like(s) }
      }
    end

    @shows.any?
  end

  def year_range(year1, year2)
    validate_sorting_for_year_or_scope
    @shows = Show.avail
                 .between_years(year1, year2)
                 .includes(:tour, :venue, :tags)
                 .order(@order_by)
    @sections = {}
    @shows.group_by(&:tour_name).each do |tour, show_list|
      @sections[tour] = {
        shows: show_list,
        likes: show_list.map { |s| get_user_show_like(s) }
      }
    end

    @shows.any?
  end

  def show(date)
    # convert 2012.12.31 to 2012-12-31
    matches = Regexp.last_match
    date = "#{matches[1]}-#{matches[2]}-#{matches[3]}" if date =~ /\A(\d{4})\.(\d{1,2})\.(\d{1,2})\z/

    # Ensure valid date before touching database
    begin
      Date.parse(date)
    rescue ArgumentError
      return false
    end

    @show = Show.where(date: date)
                .includes(tracks: %i[songs tags])
                .order('tracks.position asc')
                .first
    return false unless @show.present?

    @sets = {}
    tracks = @show.tracks
    tracks.group_by(&:set_name).each do |set, track_list|
      @sets[set] = {
        duration: track_list.map(&:duration).inject(0, &:+),
        tracks: track_list,
        likes: track_list.map { |t| get_user_track_like(t) }
      }
    end
    @show_like = get_user_show_like(@show)

    set_next_show
    set_previous_show

    true
  end

  def set_next_show
    @next_show =
      Show.avail
          .where('date > ?', @show.date)
          .order(date: :asc)
          .first
    @next_show ||=
      Show.avail
          .order(date: :asc)
          .first
  end

  def set_previous_show
    @previous_show =
      Show.avail
          .where('date < ?', @show.date)
          .order(date: :desc)
          .first
    @previous_show ||=
      Show.avail
          .order(date: :desc)
          .first if @previous_show.nil?
  end

  def song(slug)
    validate_sorting_for_song

    @song = Song.where(slug: slug.downcase).first
    return false unless @song.present?

    if @song.alias_for
      aliased_song = Song.where(id: @song.alias_for).first
      @redirect = "/#{aliased_song.slug}"
    else
      @tracks = @song.tracks
                     .includes({ show: :venue }, :songs, :tags)
                     .order(@order_by)
                     .paginate(page: params[:page], per_page: 20)
      @next_song = Song.relevant.where('title > ?', @song.title).order(title: :asc).first
      @next_song ||= Song.relevant.order(title: :asc).first
      @previous_song = Song.relevant.where('title < ?', @song.title).order(title: :desc).first
      @previous_song ||= Song.relevant.order(title: :desc).first
      @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
    end

    true
  end

  def venue(slug)
    validate_sorting_for_year_or_scope

    @venue = Venue.where(slug: slug.downcase).first
    return false unless @venue.present?

    @shows = @venue.shows.includes(:tags).order(@order_by)
    @shows_likes = @shows.map { |show| get_user_show_like(show) }
    @next_venue = Venue.relevant.where('name > ?', @venue.name).order(name: :asc).first
    @next_venue = Venue.relevant.order(name: :asc).first if @next_venue.nil?
    @previous_venue = Venue.relevant.where('name < ?', @venue.name).order(name: :desc).first
    @previous_venue = Venue.relevant.order(name: :desc).first if @previous_venue.nil?

    true
  end

  def tour(slug)
    @tour = Tour.where(slug: slug.downcase).includes(:shows).first
    return false unless @tour.present?

    @shows = @tour.shows.includes(:tags).order(date: :desc)
    @shows_likes = @shows.map { |show| get_user_show_like(show) }
    @sections = { @tour.name => { shows: @shows, likes: [] } }

    true
  end

  def validate_sorting_for_year_or_scope
    params[:sort] = 'date desc' unless ['date desc', 'date asc', 'likes', 'duration'].include?(params[:sort])
    set_order_by_for_year_or_scope
  end

  def set_order_by_for_year_or_scope
    if ['date asc', 'date desc'].include?(params[:sort])
      @order_by = params[:sort]
    elsif params[:sort] == 'likes'
      @order_by = 'likes_count desc, date desc'
    elsif params[:sort] == 'duration'
      @order_by = 'shows.duration, date desc'
    end
  end

  def validate_sorting_for_song
    params[:sort] = 'date desc' unless ['date desc', 'date asc', 'likes', 'duration'].include?(params[:sort])
    set_order_by_for_song
  end

  def set_order_by_for_song
    @order_by = if ['date asc', 'date desc'].include?(params[:sort])
                  params[:sort].gsub(/date/, 'shows.date')
                elsif params[:sort] == 'likes'
                  'tracks.likes_count desc, shows.date desc'
                elsif params[:sort] == 'duration'
                  'tracks.duration, shows.date desc'
                end
  end

  def songs_order_by
    params[:sort] = 'title' unless %w(title performances).include?(params[:sort])

    if params[:sort] == 'title'
      order_by = 'title asc'
    elsif params[:sort] == 'performances'
      order_by = 'tracks_count desc, title asc'
    end

    order_by
  end

  def venues_order_by
    params[:sort] = 'name' unless %w(name performances).include?(params[:sort])

    if params[:sort] == 'name'
      order_by = 'name asc'
    elsif params[:sort] == 'performances'
      order_by = 'shows_count desc, name asc'
    end

    order_by
  end

  def char_param
    params[:char] = (FIRST_CHAR_LIST.include?(params[:char]) ? params[:char] : FIRST_CHAR_LIST.first)
  end
end