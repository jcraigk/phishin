class PlaylistBookmark < ActiveRecord::Base
  attr_accessible :user_id, :player_id

  belongs_to :playlist
  belongs_to :user
  
end
