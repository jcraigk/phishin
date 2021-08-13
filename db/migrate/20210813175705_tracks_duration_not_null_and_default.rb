class TracksDurationNotNullAndDefault < ActiveRecord::Migration[6.1]
  def change
    change_column :tracks, :duration, :integer, default: 0, null: false
  end
end
