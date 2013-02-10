class Tour < ActiveRecord::Base
  attr_accessible :name, :starts_on, :ends_on
  
  has_many :shows
  
  extend FriendlyId
  friendly_id :name, :use => :slugged

end