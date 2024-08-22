class SorceryExternal < ActiveRecord::Migration[7.2]
  def change
    create_table :authentications do |t|
      t.references :user
      t.string :provider, :uid, null: false
      t.timestamps null: false
    end

    add_index :authentications, %i[provider uid]
  end
end
