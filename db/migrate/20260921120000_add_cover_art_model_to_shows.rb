class AddCoverArtModelToShows < ActiveRecord::Migration[8.1]
  LEGACY_MODEL = "openai/gpt-image-2.5-sunburst".freeze

  def up
    add_column :shows, :cover_art_model, :string
    execute <<~SQL
      UPDATE shows SET cover_art_model = '#{LEGACY_MODEL}'
      WHERE id IN (
        SELECT record_id FROM active_storage_attachments
        WHERE record_type = 'Show' AND name = 'cover_art'
      )
    SQL
  end

  def down
    remove_column :shows, :cover_art_model
  end
end
