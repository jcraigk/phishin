class RenameTranscriptionTranscript < ActiveRecord::Migration[5.2]
  def change
    rename_column :track_tags, :transcription, :transcript
  end
end
