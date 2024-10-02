class AudioFileUploader < PhishinUploader
  def generate_location(_io, record: nil, _name: nil, **)
    "tracks/audio_files/#{partition_path(record)}/#{record.id}.mp3"
  end
end
