# frozen_string_literal: true
class AddTimestampsToTags < ActiveRecord::Migration[5.2]
  def change
    add_column :track_tags, :starts_at_second, :integer
    add_column :track_tags, :ends_at_second, :integer
  end
end
