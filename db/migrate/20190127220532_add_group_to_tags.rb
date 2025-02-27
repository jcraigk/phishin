class AddGroupToTags < ActiveRecord::Migration[5.2]
  def change
    add_column :tags, :group, :string, null: false, default: ''
  end
end
