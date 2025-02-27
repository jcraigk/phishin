class AddTranscriptionToTrackTag < ActiveRecord::Migration[5.2]
  def change
    add_column :track_tags, :transcription, :text
  end
end
