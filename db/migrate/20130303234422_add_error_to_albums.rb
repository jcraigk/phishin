class AddErrorToAlbums < ActiveRecord::Migration
  def change
    add_column :albums, :error_at, :datetime
  end
end
