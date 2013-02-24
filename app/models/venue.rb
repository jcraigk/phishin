class Venue < ActiveRecord::Base
  attr_accessible :name, :past_names, :city, :state, :country, :shows_count
  
  has_many :shows
  
  extend FriendlyId
  friendly_id :name, :use => :slugged
  
  scope :relevant, -> { where("shows_count > 0") }
  
  def location
    country == "USA" ? "#{city}, #{state}" : "#{city}, #{state} #{country}"
  end
  
  def name_letter
    name[0,1]
  end

end