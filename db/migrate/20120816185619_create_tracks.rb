class CreateTracks < ActiveRecord::Migration
  def change
    create_table :tracks do |t|
      t.references  :show
      t.string      :title
      t.integer     :position
      t.integer     :duration
      t.timestamps
    end
    
    add_index :tracks, :show_id
  end
end
