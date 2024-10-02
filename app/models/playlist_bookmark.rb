# TODO: Delete me after React deploy!

class PlaylistBookmark < ApplicationRecord
  belongs_to :playlist
  belongs_to :user
end
