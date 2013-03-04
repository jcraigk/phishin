class Album < ActiveRecord::Base
  
  #########################
  # Attributes & Constants
  #########################
  attr_accessible :name, :md5, :is_custom_playlist, :completed_at, :updated_at, :error_at

  has_attached_file :zip_file,
    path: APP_CONTENT_PATH + ":class/cache/:id.:extension"
  
  scope :completed, -> { where("completed_at IS NOT NULL") }
  
  def self.cache_used
    cache_size = 0
    self.completed.all.each { |album| cache_size += album.zip_file.size }
    cache_size
  end
  
end
