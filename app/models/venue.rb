class Venue < ActiveRecord::Base
  attr_accessible :name, :past_names, :city, :state, :country, :shows_count, :latitude, :longitude
  
  has_many :shows
  
  extend FriendlyId
  friendly_id :name, :use => :slugged
  
  geocoded_by :address
  
  scope :relevant, -> { where("shows_count > 0") }
  scope :name_starting_with, ->(char) { where("name SIMILAR TO ?", "#{char == '#' ? '[0-9]' : char}%") }
  
  def name_and_abbrev
    abbrev ? "#{name} (#{abbrev})" : name
  end
  
  def location
    (country == "USA" ? "#{city}, #{state}" : "#{city}, #{state} #{country}").gsub(/\s+/, ' ')
  end
  
  def address
    "#{name}, #{location}"
  end
  
  def name_letter
    name[0,1]
  end
  
  def as_json(options={})
    {
      name: name,
      past_names: past_names,
      latitude: latitude,
      longitude: longitude,
      shows_count: shows_count,
      location: location,
      slug: slug,
      show_dates: shows.order('date desc').all.map(&:date)
    }
  end

end