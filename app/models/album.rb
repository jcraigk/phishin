class Album < ActiveRecord::Base
  
  #########################
  # Attributes & Constants
  #########################
  FILE_NAME_HASH_SECRET = "CROUOPQNDKUCBVYTQYQLUSKCOMJAQFEWXMEX"
  attr_accessible :name, :md5, :is_custom_playlist, :completed_at, :updated_at

  has_attached_file :zip_file,
    :url => "/system/:class/:attachment/:hash.:extension",
    :hash_secret => FILE_NAME_HASH_SECRET
  
  def self.completed
    where("completed_at IS NOT NULL")
  end
  
end
