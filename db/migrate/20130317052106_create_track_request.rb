class CreateTrackRequest < ActiveRecord::Migration
  def change
    create_table :requests do |t|
      t.integer     :track_id
      t.integer     :user_id
      t.string      :type
      t.datetime    :created_at
    end
  end
end
