class RemoveAltTitle < ActiveRecord::Migration[5.2]
  def change
    remove_column :songs, :alt_title, :string if column_exists?(:songs, :alt_title)
  end
end
