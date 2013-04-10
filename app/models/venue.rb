class Venue < ActiveRecord::Base
  attr_accessible :name, :past_names, :city, :state, :country, :shows_count, :latitude, :longitude
  
  has_many :shows
  
  extend FriendlyId
  friendly_id :name, :use => :slugged
  
  geocoded_by :address
  
  scope :relevant, -> { where("shows_count > 0") }
  
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
      vague_location: vague_location,
      location: location,
      slug: slug,
      show_dates: shows.order('date desc').all.map(&:date)
    }
  end

end