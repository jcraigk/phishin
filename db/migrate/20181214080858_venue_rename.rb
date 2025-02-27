class VenueRename < ActiveRecord::Migration[5.2]
  def change
    create_table :venue_renames do |t|
      t.integer :venue_id
      t.string :name, null: false
      t.date :renamed_on, null: false
    end

    add_index :venue_renames, :venue_id
    add_index :venue_renames, %i[name renamed_on], unique: true

    remove_index :shows, name: 'index_shows_on_date'
    add_index :shows, :date, unique: true
  end
end
