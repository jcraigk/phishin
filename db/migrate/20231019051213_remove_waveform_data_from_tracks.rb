class RemoveWaveformDataFromTracks < ActiveRecord::Migration[7.1]
  def change
    remove_column :tracks, :waveform_data, :jsonb
  end
end
