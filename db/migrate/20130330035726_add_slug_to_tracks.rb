class AddSlugToTracks < ActiveRecord::Migration
  def change
    add_column :tracks, :slug, :string

    # Add indexes for all slugs
    add_index :tracks, :slug
    add_index :venues, :slug, unique: true
    add_index :tours, :slug, unique: true
  end
end
