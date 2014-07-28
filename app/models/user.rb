class User < ActiveRecord::Base
  attr_accessible :email, :password, :password_confirmation, :remember_me, :username
  
  has_many :playlists, dependent: :destroy
  has_many :playlist_bookmarks, dependent: :destroy
  has_many :likes, dependent: :destroy
  
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  
  validates :username, uniqueness: true, format: { with: /^[A-Za-z0-9_]{4,15}$/, message: 'may contain only letters, numbers, and underscores; must be unique; and must be 4 to 15 characters long' }
  
end
