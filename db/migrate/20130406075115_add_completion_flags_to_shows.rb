# frozen_string_literal: true
class AddCompletionFlagsToShows < ActiveRecord::Migration
  def change
    add_column :shows, :incomplete, :boolean, default: false
    add_column :shows, :missing, :boolean, default: true
  end
end
