class Album < ActiveRecord::Base
  
  #########################
  # Attributes & Constants
  #########################
  attr_accessible :name, :md5, :is_custom_playlist, :completed_at, :updated_at

  has_attached_file :audio_file,
    path: PAPERCLIP_BASE_DIR + "/:class/:attachment/:id_partition/:style/:hash.:extension",
    hash_secret: PAPERCLIP_SECRET
  
  def self.completed
    where("completed_at IS NOT NULL")
  end
  
end
