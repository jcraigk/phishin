require "mp3info"

class Id3Tagger
  attr_reader :show, :track

  def initialize(track)
    @track = track
    @show = track.show
  end

  def call
    apply_default_tags
  end

  private

  def apply_default_tags
    Mp3Info.open(track.audio_file.to_io.path) do |mp3|
      apply_tags(mp3)
      apply_v2_tags(mp3)
      mp3.tag2.remove_pictures
    end
  end

  def apply_tags(mp3)
    apply_track_specific_tags(mp3)
    mp3.tag.artist = artist
    mp3.tag.album = album[0..29]
    mp3.tag.year = year
    mp3.tag.comments = comments
  end

  def apply_track_specific_tags(mp3)
    mp3.tag.title = track.title[0..29]
    mp3.tag.tracknum = track.position
  end

  def apply_v2_tags(mp3)
    apply_track_specific_v2_tags(mp3)
    mp3.tag2.TOPE = artist
    mp3.tag2.TALB = album[0..59]
    mp3.tag2.TYER = year
    mp3.tag2.COMM = comments
  end

  def apply_track_specific_v2_tags(mp3)
    mp3.tag2.TIT2 = track.title[0..59]
    mp3.tag2.TRCK = track.position
  end

  def comments
    "#{App.base_url} for more"
  end

  def year
    @year ||= show.date.strftime("%Y").to_i
  end

  def artist
    "Phish"
  end

  def album
    @album ||= "#{show.date} #{show.venue_name}"
  end
end
