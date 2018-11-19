# frozen_string_literal: true
class DropTrackRequests < ActiveRecord::Migration[5.2]
  def change
    drop_table :track_requests
  end
end
