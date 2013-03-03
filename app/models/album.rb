class Album < ActiveRecord::Base
  
  #########################
  # Attributes & Constants
  #########################
  attr_accessible :name, :md5, :is_custom_playlist, :completed_at, :updated_at

  has_attached_file :zip_file,
    path: APP_CONTENT_PATH + ":class/cache/:id.:extension"
  
  def self.completed
    where("completed_at IS NOT NULL")
  end
  
end
