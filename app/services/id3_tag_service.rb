require "mp3info"

class Id3TagService < ApplicationService
  param :track

  def call
    apply_default_tags
    reattach_modified_audio_file
  rescue ActiveStorage::FileNotFoundError => e
    Rails.logger.error "File not found: #{e.message}"
  ensure
    @temp_audio_file&.close!
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
    @temp_audio_file = Tempfile.new([ "track_#{track.id}", ".mp3" ])
    @temp_audio_file.binmode
    @temp_audio_file.write(track.mp3_audio.download)
    @temp_audio_file.rewind
    @temp_audio_file.path
  end

  def reattach_modified_audio_file
    track.mp3_audio.attach \
      io: File.open(@temp_audio_file.path),
      filename: track.friendly_filename,
      content_type: "audio/mpeg"
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

    # Process and download the ID3 variant. A previous run may have left an
    # orphaned VariantRecord behind (row present, image attachment gone), which
    # yields a blank key and no data, so purge and regenerate when that happens.
    album_art_data = processed_id3_variant_data
    return if album_art_data.blank?

    mp3.tag2.add_picture(album_art_data)
  end

  def processed_id3_variant_data
    variant = show.album_cover.variant(:id3).processed
    return variant.download if variant.key.present?

    purge_orphaned_variant_record
    show.album_cover.reload
    show.album_cover.variant(:id3).processed.download
  end

  def purge_orphaned_variant_record
    variation_digest = show.album_cover.variant(:id3).variation.digest
    ActiveStorage::VariantRecord
      .where(blob_id: show.album_cover.blob.id, variation_digest:)
      .destroy_all
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

  def show
    @show ||= track.show
  end
end
