# frozen_string_literal: true
class AddMissingUniqueIndexes < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def change
    add_index :users, :username, unique: true, algorithm: :concurrently

    remove_index :playsts, name: 'index_playlists_on_name'
    add_index :playlists, :name, unique: true, algorithm: :concurrently
    remove_index :playsts, name: 'index_playlists_on_slug'
    add_index :playlists, :slug, unique: true, algorithm: :concurrently

    remove_index :tags, name: 'index_tags_on_name'
    add_index :tags, :name, unique: true, algorithm: :concurrently
    remove_index :tags, name: 'index_tags_on_priority'
    add_index :tags, :priority, unique: true, algorithm: :concurrently

    add_index :tracks, %i[show_id position], unique: true, algorithm: :concurrently

    add_index :show_tags, %i[tag_id show_id], unique: true, algorithm: :concurrently
    add_index :songs_tracks, %i[track_id song_id], unique: true, algorithm: :concurrently
    add_index :track_tags, %i[tag_id track_id], unique: true, algorithm: :concurrently
  end
end
