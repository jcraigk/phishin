class CreateAnnouncements < ActiveRecord::Migration[7.0]
  def change
    create_table :announcements do |t|
      t.string :title
      t.string :description
      t.string :url

      t.timestamps
    end

    add_index :announcements, :created_at
  end
end
