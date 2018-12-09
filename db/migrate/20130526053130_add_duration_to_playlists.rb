# frozen_string_literal: true
class AddDurationToPlaylists < ActiveRecord::Migration
  def change
    add_column :playlists, :duration, :integer, default: 0

    add_index :playlists, :duration
  end
end
