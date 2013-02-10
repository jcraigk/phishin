class CreateAlbums < ActiveRecord::Migration
  def change
    create_table :albums do |t|
      t.string      :name
      t.string      :md5
      t.boolean     :is_custom_playlist, :default => :false
      t.datetime    :completed_at
      t.timestamps
    end
    
    add_attachment :albums, :zip_file
    add_index :albums, :md5
  end

end
