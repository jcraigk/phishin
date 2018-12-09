# frozen_string_literal: true
class CreateLikes < ActiveRecord::Migration
  def change
    create_table :likes do |t|
      t.string      :likable_type
      t.integer     :likable_id
      t.integer     :user_id
      t.datetime    :created_at
    end

    add_column :tracks, :likes_count, :integer, default: 0
    add_column :shows, :likes_count, :integer, default: 0

    add_index :likes, :likable_id
    add_index :likes, :likable_type
    add_index :likes, :user_id
    add_index :tracks, :likes_count
    add_index :shows, :likes_count
  end
end
