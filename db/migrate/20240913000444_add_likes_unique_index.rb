class AddLikesUniqueIndex < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      DELETE FROM likes
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM likes
        GROUP BY likable_id, likable_type, user_id
      );
    SQL

    unless index_exists?(:likes, %i[ likable_id likable_type user_id ], unique: true)
      add_index :likes, %i[ likable_id likable_type user_id ], unique: true, name: 'index_likes_on_likable_and_user_uniq'
    end
  end

  def down
    remove_index :likes, name: 'index_likes_on_likable_and_user_uniq' if index_exists?(:likes, %i[ likable_id likable_type user_id], unique: true)
  end
end
