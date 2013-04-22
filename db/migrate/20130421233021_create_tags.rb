class CreateTags < ActiveRecord::Migration
  def change
    create_table :tags do |t|
      t.string      :name
      t.string      :color
      t.text        :description
      t.timestamps
    end
    
    create_table :show_tags do |t|
      t.integer   :show_id
      t.integer   :tag_id
      t.datetime  :created_at
    end
    
    create_table :track_tags do |t|
      t.integer   :track_id
      t.integer   :tag_id
      t.datetime  :created_at
    end
    
    add_index :tags, :name
    add_index :show_tags, :show_id
    add_index :show_tags, :tag_id
    add_index :track_tags, :track_id
    add_index :track_tags, :tag_id
  end
end
