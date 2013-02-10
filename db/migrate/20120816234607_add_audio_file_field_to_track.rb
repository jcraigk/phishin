class AddSongFileFieldToTrack < ActiveRecord::Migration
  def up
    add_attachment :tracks, :audio_file
  end

  def down
    remove_attachment :tracks, :audio_file
  end
end
