# frozen_string_literal: true
class AddGeocodingToVenues < ActiveRecord::Migration
  def change
    add_column :venues, :latitude, :float
    add_column :venues, :longitude, :float
    add_column :venues, :vague_location, :boolean, default: false
  end
end
