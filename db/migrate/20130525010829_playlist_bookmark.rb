# frozen_string_literal: true
class PlaylistBookmark < ActiveRecord::Migration
  def change
    create_table :playlist_bookmarks do |t|
      t.integer :user_id
      t.integer :playlist_id
    end

    add_index :playlist_bookmarks, :user_id
    add_index :playlist_bookmarks, :playlist_id
  end
end
