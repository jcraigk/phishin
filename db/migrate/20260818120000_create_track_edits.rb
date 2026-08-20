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

    # The per-track history panel selects on track_id newest first. Nullified
    # rows from a combine no longer match any track, which is why the show
    # index exists alongside it: a show's history is the only place a combined
    # track's record can still be found.
    add_index :track_edits, %i[track_id created_at]
    add_index :track_edits, %i[show_id created_at]

    # A combine destroys a track, and the record of that combine has to outlive
    # its own subject. Cascading here would erase the history exactly when an
    # admin needs it, so the reference is nullified instead.
    add_foreign_key :track_edits, :tracks, on_delete: :nullify
    add_foreign_key :track_edits, :shows, on_delete: :cascade
    add_foreign_key :track_edits, :users, on_delete: :nullify
  end
end
