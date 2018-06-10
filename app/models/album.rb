# frozen_string_literal: true
class Album < ApplicationRecord
  has_attached_file(
    :zip_file,
    path: APP_CONTENT_PATH + ':class/cache/:id.:extension'
  )

  scope :completed, -> { where('completed_at IS NOT NULL') }

  def self.cache_used
    completed.inject(0) { |sum, album| sum + album.zip_file.size }
  end
end
