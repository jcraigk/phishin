class CreateAlbumRequests < ActiveRecord::Migration
  def change
    create_table :album_requests do |t|
      t.integer     :album_id
      t.integer     :user_id
      t.string      :name
      t.string      :md5
      t.string      :kind
      t.datetime    :created_at
    end
  end
end
