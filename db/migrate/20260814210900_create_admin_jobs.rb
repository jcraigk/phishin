class CreateAdminJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_jobs do |t|
      t.string :kind, null: false
      t.integer :show_id
      t.integer :track_id
      t.string :status, null: false, default: "queued"
      t.integer :progress, null: false, default: 0
      t.text :message
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :admin_jobs, %i[show_id kind created_at]
  end
end
