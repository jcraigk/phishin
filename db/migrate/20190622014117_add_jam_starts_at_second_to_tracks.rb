# frozen_string_literal: true
class AddJamStartsAtSecondToTracks < ActiveRecord::Migration[5.2]
  def change
    add_column :tracks, :jam_starts_at_second, :integer
    add_index :tracks, :jam_starts_at_second
  end
end
