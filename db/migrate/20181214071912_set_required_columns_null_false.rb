class SetRequiredColumnsNullFalse < ActiveRecord::Migration[5.2]
  def change
    change_column_null :playlists, :name, false
    change_column_null :playlists, :slug, false
    change_column_null :shows, :date, false
    change_column_null :tours, :name, false
    change_column_null :tours, :starts_on, false
    change_column_null :tours, :ends_on, false
    change_column_null :venues, :name, false
    change_column_null :venues, :city, false
    change_column_null :venues, :country, false
    change_column_null :tags, :name, false
    change_column_null :tags, :color, false
    change_column_null :tags, :priority, false
    change_column_null :songs, :title, false
    change_column_null :tracks, :title, false
    change_column_null :tracks, :position, false
    change_column_null :tracks, :set, false
  end
end
