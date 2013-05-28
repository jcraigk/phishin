class PlaylistTrack < ActiveRecord::Base
  
  attr_accessible :playlist_id, :track_id, :position
  
  belongs_to :playlist
  belongs_to :track

  validates :position, numericality: true
  
end
