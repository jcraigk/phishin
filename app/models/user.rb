class User < ActiveRecord::Base
  attr_accessible :email, :password, :password_confirmation, :remember_me, :username
  
  has_many :playlists, dependent: :destroy
  has_many :playlist_bookmarks, dependent: :destroy
  has_many :likes, dependent: :destroy
  
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable
  
  validates :username, uniqueness: true, format: { with: /^[A-Za-z0-9_]{4,15}$/, message: 'may contain only letters, numbers, and underscores; must be unique; and must be 4 to 15 characters long' }

  # Token-based authentication for API usage (https://gist.github.com/josevalim/fb706b1e933ef01e4fb6)
  def generate_authentication_token!
    token = ''
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
    self.authentication_token = token
    self.save!
  end
end
