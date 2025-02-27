class DropRailsAdminHistories < ActiveRecord::Migration[5.2]
  def change
    drop_table :rails_admin_histories
  end
end
