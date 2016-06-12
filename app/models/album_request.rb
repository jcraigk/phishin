class AlbumRequest < ActiveRecord::Base
  attr_accessible :album_id, :user_id, :name, :md5, :kind, :created_at

  has_one :user
  has_one :album
end
