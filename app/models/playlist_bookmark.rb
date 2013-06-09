class PlaylistBookmark < ActiveRecord::Base
  attr_accessible :user_id, :playlist_id

  belongs_to :playlist
  belongs_to :user
  
end
