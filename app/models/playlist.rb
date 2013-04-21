class Playlist < ActiveRecord::Base
  
  attr_accessible :name, :slug, :user_id

  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  belongs_to :user

  validates :name, presence: true
  validates :slug, presence: true
  
end
