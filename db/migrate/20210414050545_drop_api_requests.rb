# frozen_string_literal: true
class DropApiRequests < ActiveRecord::Migration[6.1]
  def change
    drop_table :api_requests
  end
end
