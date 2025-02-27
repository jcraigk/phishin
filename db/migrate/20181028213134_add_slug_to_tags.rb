class AddSlugToTags < ActiveRecord::Migration[5.2]
  def change
    add_column :tags, :slug, :string
    add_index :tags, :slug
    add_index :tags, :priority
    add_index :tags, :description
  end
end
