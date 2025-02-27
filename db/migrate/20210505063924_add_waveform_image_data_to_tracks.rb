class AddWaveformImageDataToTracks < ActiveRecord::Migration[6.1]
  def change
    add_column :tracks, :waveform_image_data, :text
  end
end
