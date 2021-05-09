# frozen_string_literal
class AddWaveformDataToTracks < ActiveRecord::Migration[6.1]
  def change
    add_column :tracks, :waveform_data, :json
    add_column :tracks, :waveform_max, :float, index: true
  end
end
