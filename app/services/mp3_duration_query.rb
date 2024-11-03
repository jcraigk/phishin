require "mp3info"

class Mp3DurationQuery < BaseService
  param :attachment

  def call
    raise Errno::ENOENT, "File not found" unless attachment.attached?

    duration_in_seconds
  ensure
    temp_audio_file&.close!
    temp_audio_file&.unlink
  end

  private

  def temp_audio_file
    raise Errno::ENOENT, "File not found" if attachment.nil?

    @temp_audio_file ||= Tempfile.new([ "track_audio", ".mp3" ]).tap do |file|
      file.binmode
      file.write(attachment.download)
      file.rewind
    end
  end

  def duration
    Mp3Info.open(temp_audio_file.path, &:length)
  end

  def duration_in_seconds
    (duration * 1000).round
  end
end
