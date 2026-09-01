class CreateTrackEdits < ActiveRecord::Migration[8.0]
  def change
    create_table :track_edits do |t|
      t.integer :track_id
      t.integer :show_id, null: false
      t.integer :admin_job_id
      t.integer :user_id
      t.string :operation, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :track_edits, %i[track_id created_at]
    add_index :track_edits, %i[show_id created_at]

    add_foreign_key :track_edits, :tracks, on_delete: :nullify
    add_foreign_key :track_edits, :shows, on_delete: :cascade
    add_foreign_key :track_edits, :users, on_delete: :nullify
  end
end
