class DropShrineColumns < ActiveRecord::Migration[8.0]
  def change
    remove_column :tracks, :audio_file_data, :text
    remove_column :tracks, :waveform_png_data, :text
  end
end
