class AddUsernameUpdatedAtToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :username_updated_at, :datetime
  end
end
