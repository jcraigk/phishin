# frozen_string_literal: true
class AddSetToTrack < ActiveRecord::Migration
  def change
    add_column :tracks, :set, :string
  end
end
