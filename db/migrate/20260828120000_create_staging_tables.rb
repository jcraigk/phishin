class CreateStagingTables < ActiveRecord::Migration[8.0]
  def change
    create_table :staged_sources do |t|
      t.integer :show_id, null: false
      t.integer :position, null: false
      t.string :filename, null: false
      t.string :format, null: false
      t.decimal :offset_s, precision: 10, scale: 3, null: false
      t.decimal :duration_s, precision: 10, scale: 3, null: false
      t.timestamps
    end
    add_index :staged_sources, %i[show_id position], unique: true

    create_table :staged_tracks do |t|
      t.integer :show_id, null: false
      t.integer :position, null: false
      t.string :set, null: false, default: "1"
      t.string :title, null: false
      t.integer :song_id
      t.decimal :start_s, precision: 10, scale: 3, null: false
      t.decimal :end_s, precision: 10, scale: 3, null: false
      t.decimal :fade_in_s, precision: 6, scale: 2, null: false, default: 0
      t.decimal :fade_out_s, precision: 6, scale: 2, null: false, default: 0
      t.timestamps
    end
    add_index :staged_tracks, %i[show_id position], unique: true

    add_column :shows, :staging_source_url, :string
  end
end
