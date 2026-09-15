class DownloadsController < ApplicationController
  include ActiveStorage::FileServer

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
    path = ActiveStorage::Blob.service.send(:path_for, file.key)
    return head(:not_found) unless File.exist?(path)
    add_cache_header
    response.headers["Accept-Ranges"] = "bytes"
    serve_file path,
      content_type: file.content_type || "application/octet-stream",
      disposition: ActionDispatch::Http::ContentDisposition.format(disposition:, filename:)
  end

  def track
    @track ||= Track.joins(:show).merge(Show.published).includes(show: :venue).find_by(id: params[:id])
  end

  def blob
    @blob ||= ActiveStorage::Blob.find_by(key: params[:key].split(".").first)
  end

  def add_cache_header
    response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
  end
end
