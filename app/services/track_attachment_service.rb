class TrackAttachmentService < BaseService
  param :track

  def call
    convert_attachment(track.audio_file, :mp3_audio, "mp3")
    convert_attachment(track.waveform_png, :png_waveform, "png")
  end

  private

  def convert_attachment(shrine_attachment, active_storage_attachment, ext)
    return if track.public_send(active_storage_attachment).attached?
    return unless shrine_attachment&.exists?

    # Attach file to ActiveStorage
    track.public_send(active_storage_attachment).attach \
      io: shrine_attachment.download,
      filename: filename(ext),
      content_type: shrine_attachment.mime_type

    # Delete Shrine attachment if ActiveStorage attachment is successful
    # shrine_attachment.delete if track.public_send(active_storage_attachment).attached?
  end

  def filename(ext)
    "#{track.show.date} - #{format('%02d', track.position)} - #{track.title}.#{ext}"
  end
end
