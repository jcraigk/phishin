class AddAlbumZipRequestedAtToShows < ActiveRecord::Migration[7.2]
  def change
    add_column :shows, :album_zip_requested_at, :datetime
  end
end
