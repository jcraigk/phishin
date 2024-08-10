require "mp3info"

class Mp3DurationQuery
  attr_reader :mp3_file

  def initialize(mp3_file)
    @mp3_file = mp3_file
  end

  def call
    duration_in_seconds
  end

  private

  def duration
    Mp3Info.open(mp3_file, &:length)
  end

  def duration_in_seconds
    (duration * 1000).round
  end
end
