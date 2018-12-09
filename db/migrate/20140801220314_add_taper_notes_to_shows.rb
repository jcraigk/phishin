# frozen_string_literal: true
class AddTaperNotesToShows < ActiveRecord::Migration
  def change
    add_column :shows, :taper_notes, :text
  end
end
