class AddSetToTrack < ActiveRecord::Migration
  def change
    add_column :tracks, :set, :string
  end
end