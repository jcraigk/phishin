class RemoveRemasteredAndSbdFromShows < ActiveRecord::Migration[7.1]
  def change
    remove_column :shows, :remastered, :boolean, default: false
    remove_column :shows, :sbd, :boolean, default: false
  end
end
