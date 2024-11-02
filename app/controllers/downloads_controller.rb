class DownloadsController < ApplicationController
  def download_track
    raise ActiveRecord::RecordNotFound if track&.audio_file.blank?
    send_audio_file_as_attachment
  end

  def download_blob
    raise ActiveRecord::RecordNotFound if blob.blank?
    send_blob_file_inline
  end

  private

  def send_audio_file_as_attachment
    add_cache_header
    send_file \
      track.audio_file.to_io.path,
      type: "audio/mpeg",
      disposition: "attachment",
      filename: "Phish #{track.show.date} #{track.title}.mp3",
      length: track.audio_file.size
  rescue ActionController::MissingFile
    head :not_found
  end

  def send_blob_file_inline
    add_cache_header
    send_file \
      ActiveStorage::Blob.service.send(:path_for, blob.key),
      type: blob.content_type || "application/octet-stream",
      disposition: "inline",
      filename: blob.filename.to_s,
      length: blob.byte_size
  rescue ActionController::MissingFile
    head :not_found
  end

  def track
    @track ||=
      Track.includes(show: :venue)
           .find_by(id: params[:id])
  end

  def blob
    @blob ||= ActiveStorage::Blob.find_by(key: params[:key])
  end

  def add_cache_header
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
  end
end
