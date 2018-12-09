# frozen_string_literal: true
class CreateVenues < ActiveRecord::Migration
  def change
    create_table :venues do |t|
      t.string      :name
      t.string      :past_names
      t.string      :city
      t.string      :state
      t.string      :country
      t.string      :slug
      t.timestamps
    end

    add_index :venues, :name
  end
end
