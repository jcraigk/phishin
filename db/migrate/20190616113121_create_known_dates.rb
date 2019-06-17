# frozen_string_literal: true
class CreateKnownDates < ActiveRecord::Migration[5.2]
  def change
    create_table :known_dates do |t|
      t.date :date, null: false
      t.string :phishnet_url
      t.string :location
      t.string :venue
      t.timestamps
    end

    add_index :known_dates, :date, unique: true
  end
end
