# frozen_string_literal: true
class DropAlbumTables < ActiveRecord::Migration[5.2]
  def change
    drop_table :albums
    drop_table :album_requests
  end
end
