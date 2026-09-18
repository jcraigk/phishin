class CreateTrafficCounts < ActiveRecord::Migration[8.1]
  def change
    create_table :traffic_counts do |t|
      t.datetime :hour, null: false
      t.string :client, null: false
      t.boolean :logged_in, null: false, default: false
      t.string :route, null: false
      t.string :ip, null: false, default: ""
      t.string :user_agent, null: false, default: ""
      t.integer :count, null: false, default: 0
      t.timestamps
    end

    add_index :traffic_counts, %i[hour client logged_in route ip user_agent], unique: true, name: "index_traffic_counts_on_key"
    add_index :traffic_counts, :ip
    add_index :traffic_counts, :user_agent
  end
end
