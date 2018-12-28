# frozen_string_literal: true
class CreateApiRequests < ActiveRecord::Migration[5.2]
  def change
    create_table :api_requests do |t|
      t.integer :api_key_id
      t.string :path
      t.timestamps
    end
  end
end
