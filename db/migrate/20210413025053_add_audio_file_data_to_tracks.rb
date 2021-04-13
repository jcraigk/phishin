# frozen_string_literal: true
class AddAudioFileDataToTracks < ActiveRecord::Migration[6.1]
  def change
    add_column :tracks, :audio_file_data, :text
  end
end
