class AddUniqueIndexesToTours < ActiveRecord::Migration[5.2]
  def change
    remove_index :tours, name: 'index_tours_on_name'
    add_index :tours, :name, unique: true

    remove_index :tours, name: 'index_tours_on_starts_on'
    add_index :tours, :starts_on, unique: true

    add_index :tours, :ends_on, unique: true
  end
end
