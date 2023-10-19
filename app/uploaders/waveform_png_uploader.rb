class WaveformPngUploader < PhishinUploader
  def generate_location(_io, record: nil, _name: nil, **)
    "#{partition_path(record)}/waveform-#{record.id}.png"
  end
end
