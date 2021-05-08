# frozen_string_literal: true
class WaveformImageUploader < PhishinUploader
  def generate_location(_io, record: nil, _name: nil, **)
    "#{partition_path(record)}/#{record.id}.png"
  end
end
