# frozen_string_literal: true
class AddNotesToTagIntersections < ActiveRecord::Migration[5.2]
  def change
    add_column :show_tags, :notes, :text
    add_column :track_tags, :notes, :text

    add_index :show_tags, :notes
    add_index :track_tags, :notes
  end
end
