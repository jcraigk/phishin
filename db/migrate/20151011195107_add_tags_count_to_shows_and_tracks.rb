# frozen_string_literal: true
class AddTagsCountToShowsAndTracks < ActiveRecord::Migration
  def change
    add_column :shows, :tags_count, :integer, default: 0
    add_column :tracks, :tags_count, :integer, default: 0
  end
end
