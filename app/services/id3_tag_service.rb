require "mp3info"

class Id3TagService < BaseService
  param :track

  attr_reader :show

  def call
    @show = track.show
    apply_default_tags
    reattach_modified_audio_file
  rescue ActiveStorage::FileNotFoundError => e
    # puts "File not found: #{e.message}" # For dev env
  ensure
    temp_audio_file&.close! # Clean up Tempfile
  end

  private

  def apply_default_tags
    Mp3Info.open(temp_audio_file_path) do |mp3|
      apply_tags(mp3)
      apply_v2_tags(mp3)
      mp3.tag2.remove_pictures
      apply_album_art(mp3)
    end
  end

  def temp_audio_file_path
    @temp_audio_file = Tempfile.new(["track_#{track.id}", ".mp3"])
    @temp_audio_file.binmode
    @temp_audio_file.write(track.mp3_audio.download)
    @temp_audio_file.rewind
    @temp_audio_file.path
  end

  def reattach_modified_audio_file
    track.mp3_audio.attach(
      io: File.open(@temp_audio_file.path),
      filename: "#{track.id}.mp3",
      content_type: "audio/mpeg"
    )
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

  def apply_album_art(mp3)
    return unless show.album_cover.attached?
    album_cover_variant = show.album_cover.variant(:id3).processed
    album_art_data = album_cover_variant.download
    mp3.tag2.add_picture(album_art_data)
    album_cover_variant.blob.purge
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
