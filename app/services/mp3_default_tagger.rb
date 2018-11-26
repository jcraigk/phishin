# frozen_string_literal: true
class Mp3DefaultTagger
  attr_reader :track

  def initialize(track)
    @track = track
  end

  def call
    apply_default_tags
  end

  private

  def apply_default_tags
    Mp3Info.open(track.audio_file.path) do |mp3|
      hydrate_tags(mp3)
      hydrate_v2_tags(mp3)
      # add_cover_art # TODO: Add cover art using id3v2? or strip it be default?
    end
  end

  def add_cover_art
    mp3.tag2.remove_pictures
    mp3.tag2.add_picture('...')
  end

  def hydrate_tags(mp3)
    hydrate_track_specific_tags(mp3)
    mp3.tag.genre = 17 # Rock
    mp3.tag.artist = band
    mp3.tag.album = album_name
    mp3.tag.year = year
    mp3.tag.comments = comments
  end

  def hydrate_track_specific_tags(mp3)
    mp3.tag.title = track.title
    mp3.tag.track = track.position
  end

  def hydrate_v2_tags(mp3)
    hydrate_track_specific_v2_tags(mp3)
    mp3.tag2.genre = 'Rock'
    mp3.tag2.artist = band
    mp3.tag2.album = album_name
    mp3.tag2.year = year
    mp3.tag2.comments = comments
  end

  def hydrate_track_specific_v2_tags(mp3)
    mp3.tag2.title = track.title
    mp3.tag2.track = track.position
  end

  def show
    @show ||= track.show
  end

  def comments
    'Visit http://phish.in for free Phish audio'
  end

  def year
    @year ||= show.date.strftime('%Y').to_i
  end

  def band
    'Phish'
  end

  def album_name
    @album_name ||= "#{show.date} #{show.venue.location}"
  end
end
