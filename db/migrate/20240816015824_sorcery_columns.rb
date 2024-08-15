class SorceryColumns < ActiveRecord::Migration[7.2]
  def change
    rename_column :users, :encrypted_password, :crypted_password
    add_column :users, :salt, :string

    add_column :users, :remember_me_token, :string, default: nil
    add_column :users, :remember_me_token_expires_at, :datetime, default: nil
    add_index :users, :remember_me_token

    add_column :users, :reset_password_token_expires_at, :datetime, default: nil
    add_column :users, :reset_password_email_sent_at, :datetime, default: nil
    add_column :users, :access_count_to_reset_password_page, :integer, default: 0
  end
end
