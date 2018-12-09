# frozen_string_literal: true
class AddCounterCachesToVenuesAndTours < ActiveRecord::Migration
  def change
    add_column :venues, :shows_count, :integer, default: 0
    add_column :tours, :shows_count, :integer, default: 0
  end
end
