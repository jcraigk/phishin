# frozen_string_literal: true
class MoreIndexesAndCleanup < ActiveRecord::Migration[5.2]
  def change
    remove_column :songs, :alt_title, :string
    add_index :songs, :slug, unique: true
    add_index :songs, :title, unique: true

    remove_index :tags, name: 'index_tags_on_slug'
    add_index :tags, :slug, unique: true

    remove_index :tracks, name: 'index_tracks_on_show_id'
    add_index :tracks, %i[show_id slug], unique: true

    remove_index :venues, name: 'index_venues_on_name'
    add_index :venues, %i[name city], unique: true
    remove_index :venues, name: 'index_venues_on_slug'
    add_index :venues, :slug, unique: true

    change_column_null :songs, :title, false

    change_column_null :songs, :slug, false
    change_column_null :tracks, :slug, false
    change_column_null :playlists, :slug, false
    change_column_null :tags, :slug, false
    change_column_null :tours, :slug, false
    change_column_null :tracks, :slug, false
    change_column_null :venues, :slug, false

    change_column_null :tracks, :title, false
    change_column_null :tracks, :set, false

    change_column_null :venues, :name, false
    change_column_null :venues, :city, false
    change_column_null :venues, :state, false
    change_column_null :venues, :country, false
  end
end
