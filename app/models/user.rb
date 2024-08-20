class User < ApplicationRecord
  include SorceryAuthenticable

  has_many :playlists, dependent: :destroy
  has_many :playlist_bookmarks, dependent: :destroy
  has_many :likes, dependent: :destroy

  validates \
    :username,
    presence: true,
    uniqueness: true,
    format: {
      with: /\A[A-Za-z0-9_]{4,15}\z/,
      message: "may contain only letters, numbers, and " \
               "underscores, must be unique, and must be " \
               "4 to 15 characters long"
    }

  before_save :assign_username_from_email

  def assign_username_from_email
    name = email.split("@").first.gsub(/[^A-Za-z0-9_]/, "_")
    name = "#{name}_#{SecureRandom.hex(4)}" if User.where(username: name).exists?
    self.username = name
  end
end
