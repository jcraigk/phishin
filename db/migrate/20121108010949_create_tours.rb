class CreateTours < ActiveRecord::Migration
  def change
    create_table :tours do |t|
      t.string      :name
      t.date        :starts_on
      t.date        :ends_on
      t.string      :slug
      t.timestamps
    end

    add_index :tours, :name
    add_index :tours, :starts_on
  end
end
