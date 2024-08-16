class SorceryColumns < ActiveRecord::Migration[7.2]
  def change
    rename_column :users, :encrypted_password, :crypted_password
    add_column :users, :salt, :string

    add_column :users, :reset_password_token_expires_at, :datetime, default: nil
    add_column :users, :reset_password_email_sent_at, :datetime, default: nil
    add_column :users, :access_count_to_reset_password_page, :integer, default: 0

    add_column :users, :activation_state, :string, default: nil
    add_column :users, :activation_token, :string, default: nil
    add_column :users, :activation_token_expires_at, :datetime, default: nil

    add_index :users, :activation_token
  end
end
