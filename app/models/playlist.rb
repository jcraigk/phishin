class Playlist < ActiveRecord::Base
  
  attr_accessible :name, :slug

  has_many :tracks
  belongs_to :user

  validates :name, presence: true
  validates :slug, presence: true
  
end
