class ContentController < ApplicationController
  caches_action :years,  expires_in: CACHE_TTL
  caches_action :songs,  cache_path: proc { |c| c.request.url }, expires_in: CACHE_TTL
  caches_action :venues, cache_path: proc { |c| c.request.url }, expires_in: CACHE_TTL

  ###############################
  # Hard-coded actions
  ###############################

  def years
    render layout: false if request.xhr?
  end

  def songs
    @songs = Song.relevant.title_starting_with(char_param).order(songs_order_by)
    render layout: false if request.xhr?
  end

  def venues
    @venues = Venue.relevant.name_starting_with(char_param).order(venues_order_by)
    render layout: false if request.xhr?
  end

  def map
    params[:date_start] ||= '1983-01-01'
    params[:date_stop]  ||= Date.today.to_s
    render layout: false if request.xhr?
  end

  def top_liked_shows
    @shows = Show.avail.where('likes_count > 0').includes(:venue, :tags).order('likes_count desc, date desc').limit(40)
    @shows_likes = @shows.map { |show| get_user_show_like(show) }
    render layout: false if request.xhr?
  end

  def top_liked_tracks
    @tracks = Track.where('likes_count > 0').includes(:show, :tags).order('likes_count desc, title asc').limit(40)
    @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
    render layout: false if request.xhr?
  end

  ###############################
  # Glob matching
  ###############################
  def glob
    g = params[:glob]

    # Day of Year?
    if monthday = g.match(/^(january|february|march|april|may|june|july|august|september|october|november|december)-(\d{1,2})$/i)
      if day_of_year(Date::MONTHNAMES.index(monthday[1].titleize), Integer(monthday[2], 10))
        @title = "#{monthday[1].titleize} #{Integer(monthday[2], 10)}"
        view = :year_or_scope
      else
        view = :show_not_found
      end
    # Year?
    elsif g =~ /^\d{4}$/
      if year g
        @title = g
        @controller_action = 'year'
        view = :year_or_scope
      else
        redirect_to :root
      end
    # Year range?
    elsif years = g.match(/^(\d{4})-(\d{4})$/)
      if year_range years[1], years[2]
        @title = "#{$1} - #{$2}"
        view = :year_or_scope
        @controller_action = 'year_range'
      else
        redirect_to :root
      end
    # Show?
    elsif g =~ /^\d{4}(\-|\.)\d{1,2}(\-|\.)\d{1,2}$/
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

  def day_of_year(month, day)
    validate_sorting_for_year_or_scope
    @shows = Show.avail
                 .where('extract(month from date) = ?', month)
                 .where('extract(day from date) = ?', day)
                 .includes(:tour, :venue, :tags)
                 .order(@order_by)
                 .all

    @shows_likes = @shows.map { |show| get_user_show_like(show) }
    @shows
  end

  def year(year)
    validate_sorting_for_year_or_scope
    @shows = Show.avail
                 .during_year(year)
                 .includes(:tour, :venue, :tags)
                 .order(@order_by)
                 .all
    @shows_likes = @shows.map { |show| get_user_show_like(show) }
    @shows
  end

  def year_range(year1, year2)
    validate_sorting_for_year_or_scope
    @shows = Show.avail
                 .between_years(year1, year2)
                 .includes(:tour, :venue, :tags)
                 .order(@order_by)
                 .all
    @shows_likes = @shows.map {|show| get_user_show_like(show) }
    @shows
  end

  def show(date)
    # convert 2012.12.31 to 2012-12-31
    date = "#{$1}-#{$2}-#{$3}" if date =~ /^(\d{4})\.(\d{1,2})\.(\d{1,2})$/

    # Ensure valid date before touching database
    begin
      Date.parse(date)
    rescue
      return false
    end

    @show = Show.where(date: date).includes(:tracks).order('tracks.position asc').first
    if @show.present?
      @show_like = get_user_show_like(@show)
      @tracks = @show.tracks.includes(:songs, :tags).order('position asc')
      @set_durations = {}
      @tracks.group_by(&:set).each do |set, tracks|
        @set_durations[set] = tracks.map(&:duration).inject(0, &:+)
      end
      @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
      @next_show = Show.avail.where('date > ?', @show.date).order('date asc').first
      @next_show = Show.avail.order('date asc').first if @next_show.nil?
      @previous_show = Show.avail.where('date < ?', @show.date).order('date desc').first
      @previous_show = Show.avail.order('date desc').first if @previous_show.nil?
    end

    @show
  end

  def song(slug)
    validate_sorting_for_song

    @song = Song.where(slug: slug.downcase).first
    if @song.present?
      if @song.alias_for
        aliased_song = Song.where(id: @song.alias_for).first
        @redirect = "/#{aliased_song.slug}"
      else
        @tracks = @song.tracks
                       .includes({ show: :venue }, :songs, :tags)
                       .order(@order_by)
                       .paginate(page: params[:page], per_page: 20)
        @next_song = Song.relevant.where('title > ?', @song.title).order('title asc').first
        @next_song = Song.relevant.order('title asc').first @next_song.nil?
        @previous_song = Song.relevant.where('title < ?', @song.title).order('title desc').first
        @previous_song = Song.relevant.order('title desc').first if @previous_song.nil?
        @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
      end
    end

    @song
  end

  def venue(slug)
    validate_sorting_for_year_or_scope

    @venue = Venue.where(slug: slug.downcase).first
    if @venue.present?
      @shows = @venue.shows.includes(:tags).order(@order_by)
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
      @next_venue = Venue.relevant.where('name > ?', @venue.name).order('name asc').first
      @next_venue = Venue.relevant.order('name asc').first if @next_venue.nil?
      @previous_venue = Venue.relevant.where('name < ?', @venue.name).order('name desc').first
      @previous_venue = Venue.relevant.order('name desc').first if @previous_venue.nil?
    end
    @display_separators = false

    @venue
  end

  def tour(slug)
    @tour = Tour.where(slug: slug.downcase).includes(:shows).first
    if @tour.present?
      @shows = @tour.shows.includes(:tags).order('date desc')
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end

    @tour
  end

  def validate_sorting_for_year_or_scope
    params[:sort] = 'date desc' unless ['date desc', 'date asc', 'likes', 'duration'].include?(params[:sort])
    set_order_by_for_year_or_scope
  end

  def set_order_by_for_year_or_scope
    if ['date asc', 'date desc'].include?(params[:sort])
      @order_by = params[:sort]
      @display_separators = true
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
