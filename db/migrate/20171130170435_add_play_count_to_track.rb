class AddPlayCountToTrack < ActiveRecord::Migration
  def change
    add_column :tracks, :play_count, :integer, default: 0
  end
end
