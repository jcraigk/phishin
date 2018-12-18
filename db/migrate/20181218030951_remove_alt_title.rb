# frozen_string_literal: true
class RemoveAltTitle < ActiveRecord::Migration[5.2]
  def change
    remove_column :songs, :alt_title, :string
  end
end
