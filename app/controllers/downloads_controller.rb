class DownloadsController < ApplicationController
  def download_track
    raise ActiveRecord::RecordNotFound if track.blank?
    return head(:not_found) unless track.mp3_audio.attached?
    send_file_response(track.mp3_audio, "attachment", track.mp3_audio.blob.filename.to_s)
  end

  def download_blob
    raise ActiveRecord::RecordNotFound if blob.blank?
    send_file_response(blob, "inline", blob.filename.to_s)
  end

  private

  def send_file_response(file, disposition, filename)
    add_cache_header
    send_file \
      ActiveStorage::Blob.service.send(:path_for, file.key),
      type: file.content_type || "application/octet-stream",
      disposition:,
      filename:,
      length: file.byte_size
  rescue ActionController::MissingFile
    head :not_found
  end

  def track
    @track ||= Track.includes(show: :venue).find_by(id: params[:id])
  end

  def blob
    @blob ||= ActiveStorage::Blob.find_by(key: params[:key].split(".").first)
  end

  def add_cache_header
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
  end
end
