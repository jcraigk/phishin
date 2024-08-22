class User < ApplicationRecord
  include SorceryAuthenticable

  has_many :playlists, dependent: :destroy
  has_many :playlist_bookmarks, dependent: :destroy
  has_many :likes, dependent: :destroy
end
