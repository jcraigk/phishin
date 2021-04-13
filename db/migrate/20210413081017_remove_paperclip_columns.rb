# frozen_string_literal: true
class RemovePaperclipColumns < ActiveRecord::Migration[6.1]
  def change
    remove_column :tracks, :audio_file_file_name
    remove_column :tracks, :audio_file_content_type
    remove_column :tracks, :audio_file_file_size
    remove_column :tracks, :audio_file_updated_at
  end
end
