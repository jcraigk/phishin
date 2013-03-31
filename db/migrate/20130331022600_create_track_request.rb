class CreateTrackRequest < ActiveRecord::Migration
  def change
    create_table :track_requests do |t|
      t.integer     :track_id
      t.integer     :user_id
      t.string      :kind
      t.datetime    :created_at
    end
  end
end
