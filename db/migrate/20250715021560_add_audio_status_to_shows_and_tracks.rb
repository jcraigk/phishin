class AddAudioStatusToShowsAndTracks < ActiveRecord::Migration[8.0]
  def change
    add_column :shows, :audio_status, :string, null: false, default: 'complete'
    add_column :tracks, :audio_status, :string, null: false, default: 'complete'

    add_index :shows, :audio_status
    add_index :tracks, :audio_status
  end
end
