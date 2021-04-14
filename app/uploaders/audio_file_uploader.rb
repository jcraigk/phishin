# frozen_string_literal: true
class AudioFileUploader < Shrine
  # Example: 000/034/100/34100.mp3
  def generate_location(_io, record: nil, _name: nil, **)
    [
      record.id.to_s.rjust(9, '0').gsub(/(.{3})(?=.)/, '\1/\2'),
      "#{record.id}.mp3"
    ].compact.join('/')
  end
end
