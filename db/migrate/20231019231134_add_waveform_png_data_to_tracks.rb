class AddWaveformPngDataToTracks < ActiveRecord::Migration[7.1]
  def change
    add_column :tracks, :waveform_png_data, :text
  end
end
