class Venue < ActiveRecord::Base
  attr_accessible :name, :past_names, :city, :state, :country
  
  has_many :shows
  
  extend FriendlyId
  friendly_id :name, :use => :slugged
  
  def location
    country == "USA" ? "#{city}, #{state}" : "#{city}, #{state} #{country}"
  end

end