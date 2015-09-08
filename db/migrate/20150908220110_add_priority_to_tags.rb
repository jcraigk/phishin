class AddPriorityToTags < ActiveRecord::Migration
  def change
    add_column :tags, :priority, :integer, default: 0
  end
end
