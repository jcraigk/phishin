# frozen_string_literal: true
class AddOriginalToSongs < ActiveRecord::Migration[5.2]
  def change
    add_column :songs, :original, :bool, null: false, default: false
    add_index :songs, :original
  end
end
