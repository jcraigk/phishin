# frozen_string_literal: true
class AddUsernameToUsers < ActiveRecord::Migration
  def change
    add_column :users, :username, :string, null: false, default: ''
  end
end
