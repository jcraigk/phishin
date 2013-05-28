class Playlist < ActiveRecord::Base
  
  attr_accessible :name, :slug, :user_id, :duration

  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_many :playlist_bookmarks, dependent: :destroy
  belongs_to :user

  validates :name, presence: true
  validates :slug, presence: true
  
end
