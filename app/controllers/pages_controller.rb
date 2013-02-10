class PagesController < ApplicationController

  def years
  end
  
  def songs
  end
  
  def cities
  end

  def venues
  end
  
  def liked
  end
  
  def glob
    g = params[:glob]
    
    # Show date?
    if g.match(/^\d{4}\-\d{2}-\d{2}$/)
      if show g
        render :show
      else
        render :show_error
      end
    else
      # Song?
      if song g
        render :song
      # City?
      elsif city g
        render :city
      # Venue?
      elsif venue g
        render :venue
      else
        redirect_to :root
      end
    end
  end
  
  private
  
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
    @song = Song.where(slug: slug).includes(:tracks).first
    @song
  end
  
  def venue(slug)
    @venue = Venue.where(slug: slug).includes(:shows).first
    @venue
  end
  
  def city(slug)
    #TODO
    false
  end
  
end