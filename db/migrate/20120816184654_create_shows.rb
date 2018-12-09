# frozen_string_literal: true
class CreateShows < ActiveRecord::Migration
  def change
    create_table :shows do |t|
      t.date        :date
      t.string      :location
      t.boolean     :remastered,  default: false
      t.boolean     :sbd,         default: false
      t.timestamps
    end
  end
end
