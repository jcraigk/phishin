class RemoveWaveformImageFromTracks < ActiveRecord::Migration[7.1]
  def change
    remove_column :tracks, :waveform_image_data, :text
  end
end
