class AddAdminNotesToShows < ActiveRecord::Migration
  def change
    add_column :shows, :admin_notes, :text
  end
end
