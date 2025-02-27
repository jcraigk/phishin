class CreateApiKeys < ActiveRecord::Migration[5.2]
  def change
    create_table :api_keys do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :key, null: false
      t.timestamp :revoked_at
      t.timestamps
    end

    add_index :api_keys, :name, unique: true
    add_index :api_keys, :email, unique: true
    add_index :api_keys, :key, unique: true
  end
end
