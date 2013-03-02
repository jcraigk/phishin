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
      @display_separators = true
    elsif params[:sort] == 'performances'
      order_by = "tracks_count desc, title asc"
      @display_separators = false
    end
    @songs = Song.relevant.order(order_by)
    render layout: false if request.xhr?
  end
  
  def cities
    render layout: false if request.xhr?
  end

  def venues
    params[:sort] = 'name' unless ['name', 'performances'].include? params[:sort]
    if params[:sort] == 'name'
      order_by = "name asc"
      @display_separators = true
    elsif params[:sort] == 'performances'
      order_by = "shows_count desc, name asc"
      @display_separators = false
    end
    @venues = Venue.relevant.order(order_by)
    render layout: false if request.xhr?
  end
  
  def liked
    @shows = Show.order('likes_count desc, date desc').limit(5)
    @shows_likes = @shows.map { |show| get_user_show_like(show) }
    @tracks = Track.order('likes_count desc, title asc').limit(5)
    @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
    render layout: false if request.xhr?
  end
  
  def playlist
    render layout: false if request.xhr?
  end
  
  ###############################
  # Glob-matching
  ###############################
  def glob
    g = params[:glob]
    
    # Year?
    if g.match(/^\d{4}$/)
      if year g
        @year = g
        view = :year_or_range
      else
        redirect_to :root
      end
    # Year range?
    elsif years = g.match(/^(\d{4})-(\d{4})$/)
      if year_range years[1], years[2]
        @year = g
        view = :year_or_range
      else
        redirect_to :root
      end
    # Show?
    elsif g.match(/^\d{4}\-\d{2}-\d{2}$/)
      if show g
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
      # Fall back to root
      else
        redirect_to :root and return
      end
    end
    request.xhr? ? (render view, layout: false) : (render view)
  end
  
  private
  
  def render_years_page
    request.xhr? ? (render :years, layout: false) : (render :years)
  end
  
  def year(year)
    validate_sorting_for_year_or_range
    if @shows = Show.during_year(year).includes(:tour, :venue).order(@order_by).all
      @shows_likes = @shows.map { |show| get_user_show_like(show) }
    end
    @shows
  end
  
  def year_range(year1, year2)
    validate_sorting_for_year_or_range
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
      @tracks_likes = @show.tracks.map { |track| get_user_track_like(track) }
    end
    @show
  end
  
  def song(slug)
    if @song = Song.where(slug: slug).first
      @tracks = @song.tracks.includes({:show => :venue}, :songs).order('shows.date desc')
      @tracks_likes = @tracks.map { |track| get_user_track_like(track) }
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
  
  def validate_sorting_for_year_or_range
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