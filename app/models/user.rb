class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable
  
  validates :username, presence: true, uniqueness: true, format: { with: /[A-Za-z0-9_]{4,20}/, message: 'may contain only letters, numbers, and underscores; must be unique; and must be 4 to 20 characters long' }
  
  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :username
  # attr_accessible :title, :body
  
end
