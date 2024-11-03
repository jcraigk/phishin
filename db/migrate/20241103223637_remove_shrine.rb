class RemoveShrine < ActiveRecord::Migration[7.2]
  def change
    remove_column :tracks, :audio_file_data, :text
    remove_column :tracks, :waveform_png_data, :text
  end
end
