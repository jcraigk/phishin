class ContentController < ApplicationController

  ###############################
  # Hard-coded actions
  ###############################
  def index
    render_years_page
  end

  def years
    render_years_page
  end
  
  def songs
    params[:sort] = 'title' unless ['title', 'performances'].include? params[:sort]
    if params[:sort] == 'title'
      order_by = "title asc"
    elsif params[:sort] == 'performances'
      order_by = "tracks_count desc, title asc"
    end
    @songs = Song.relevant.order(order_by).page(params[:page])
    render layout: false if request.xhr?
  end
  
  def map
    render layout: false if request.xhr?
  end

  def venues
    params[:sort] = 'name' unless ['name', 'performances'].include? params[:sort]
    if params[:sort] == 'name'
      order_by = "name asc"
    elsif params[:sort] == 'performances'
      order_by = "shows_count desc, name asc"
    end
    @venues = Venue.relevant.order(order_by).page(params[:page])
    render layout: false if request.xhr?
  end
  
  def top_liked_shows
    @shows = Show.where('likes_count > 0').order('likes_count desc, date desc').page(params[:page])
    @shows_likes = @shows.map { |show| get_user_show_like(show) }
    render layout: false if request.xhr?
  end
  
  def top_liked_tracks
    @tracks = Track.where('likes_count > 0').order('likes_count desc, title asc').page(params[:page])
    @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
    render layout: false if request.xhr?
  end
  
  ###############################
  # Glob-matching
  ###############################
  def glob
    g = params[:glob]
    
    # Day of Year?
    if monthday = g.match(/^(january|february|march|april|may|june|july|august|september|october|november|december)-(\d{1,2})$/i)
      if day_of_year Date::MONTHNAMES.index(monthday[1].titleize), Integer(monthday[2], 10)
        @title = "Day: #{monthday[1].titleize} #{Integer(monthday[2], 10)}"
        view = :year_or_scope
      else
        view = :show_not_found
      end
    # Year?
    elsif g.match(/^\d{4}$/)
      if year g
        @title = "Year: #{g}"
        view = :year_or_scope
      else
        redirect_to :root
      end
    # Year range?
    elsif years = g.match(/^(\d{4})-(\d{4})$/)
      if year_range years[1], years[2]
        @title = "Years: #{g}"
        view = :year_or_scope
      else
        redirect_to :root
      end
    # Show?
    elsif g.match(/^\d{4}\-\d{2}-\d{2}$/)
      if show g
        @autoplay = true
        view = :show
      else
        view = :show_not_found
      end
    else
      # Song?
      if song g
        view = :song
      # City?
      elsif city g
        view = :city
      # Venue?
      elsif venue g
        view = :venue
        # Tour?
      elsif tour g
        @title = @tour.name
        view = :year_or_scope
      # Fall back to root
      else
        redirect_to :root and return
      end
    end
    if @redirect
      redirect_to @redirect and return
    else
      request.xhr? ? (render view, layout: false) : (render view)
    end
  end
  
  private
  
  def render_years_page
    request.xhr? ? (render :years, layout: false) : (render :years)
  end
  
  def day_of_year(month, day)
    validate_sorting_for_year_or_scope
    if @shows = Show.where('extract(month from date) = ?', month).where('extract(day from date) = ?', day).order(@order_by).all
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end
    @shows
  end
  
  def year(year)
    validate_sorting_for_year_or_scope
    if @shows = Show.during_year(year).includes(:tour, :venue).order(@order_by).all
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end
    @shows
  end
  
  def year_range(year1, year2)
    validate_sorting_for_year_or_scope
    if @shows = Show.between_years(year1, year2).includes(:tour, :venue).order(@order_by).all
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end
    @shows
  end
  
  def show(date)
    # Ensure valid date before touching database
    begin
       Date.parse(date)
    rescue
       return false
    end
    if @show = Show.where(date: date).includes(:tracks).order('tracks.position asc').first
      @show_like = get_user_show_like(@show)
      @tracks = @show.tracks.includes(:songs).order('position asc')
      @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
      @next_show = Show.order('date asc').first unless @next_show = Show.where('date > ?', @show.date).order('date asc').first
      @previous_show = Show.order('date desc').first unless @previous_show = Show.where('date < ?', @show.date).order('date desc').first
    end
    @show
  end
  
  def song(slug)
    if @song = Song.where(slug: slug).first
      if @song.alias_for
        aliased_song = Song.where(id: @song.alias_for).first
        @redirect = "/#{aliased_song.slug}"
      else
        @tracks = @song.tracks.includes({:show => :venue}, :songs).order('shows.date desc')
        @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
      end
    end
    @song
  end
  
  def venue(slug)
    if @venue = Venue.where(slug: slug).includes(:shows).first
      @shows = @venue.shows.order('date desc')
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end
    @venue
  end

  def tour(slug)
    if @tour = Tour.where(slug: slug).includes(:shows).first
      @shows = @tour.shows.order('date desc')
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end
    @tour
  end
  
  def city(slug)
    #TODO
    false
  end
  
  def get_user_show_like(show)
    show.likes.where(user_id: current_user.id).first if show and current_user
  end
  
  def get_user_track_like(track)
    track.likes.where(user_id: current_user.id).first if track and track.likes and current_user
  end
  
  def validate_sorting_for_year_or_scope
    params[:sort] = 'date' unless ['date', 'likes'].include? params[:sort]
    if params[:sort] == 'date'
      @order_by = "date desc"
      @display_separators = true
    elsif params[:sort] == 'likes'
      @order_by = "likes_count desc, date asc"
      @display_separators = false
    end
  end
  
end