class ContentController < ApplicationController
  
  before_filter :random_lyrical_excerpt  # Pull lyrical excerpt unless XHR request

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
      @sort_display = "Sort Alphabetically"
    elsif params[:sort] == 'performances'
      order_by = "tracks_count desc, title asc"
      @display_separators = false
      @sort_display = "Sort by Performances"
    end
    @songs = Song.relevant.order(order_by)
    render layout: false if request.xhr?
  end
  
  def cities
    render layout: false if request.xhr?
  end

  def venues
    @venues = Venue.relevant.order(:name)
    render layout: false if request.xhr?
  end
  
  def liked
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
    @shows = Show.during_year(year).includes(:tour).all
    @shows
  end
  
  def year_range(year1, year2)
    @shows = Show.between_years(year1, year2).includes(:tour).all
    @shows
  end
  
  def show(date)
    # Ensure valid date before touching database
    begin
       Date.parse(date)
    rescue
       return false
    end
    @show = Show.where(date: date).includes(:tracks).first
    @show
  end
  
  def song(slug)
    @song = Song.where(slug: slug).first
    @tracks = @song.tracks.includes({:show => :venue}, :songs).order('shows.date desc') if @song
    @song
  end
  
  def venue(slug)
    @venue = Venue.where(slug: slug).includes(:shows).first
    @shows = @venue.shows.order('date desc') if @venue
    @venue
  end
  
  def city(slug)
    #TODO
    false
  end
  
  def random_lyrical_excerpt
    @random_song = Song.random_lyrical_excerpt.first unless request.xhr?
  end
  
end