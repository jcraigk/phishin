class DownloadsController < ApplicationController
  def download_show
    raise ActiveRecord::RecordNotFound unless show&.album_zip&.attached?
    send_album_zip
  end

  def download_track
    raise ActiveRecord::RecordNotFound if track&.audio_file.blank?
    send_audio_file
  end

  private

  def send_album_zip
    send_file \
      show.album_zip_path,
      type: "application/zip",
      disposition: "attachment",
      filename: "Phish #{show.date} MP3.zip",
      length: show.album_zip.blob.byte_size
  end

  def send_audio_file
    send_file \
      track.audio_file.to_io.path,
      type: "audio/mpeg",
      disposition: "attachment",
      filename: "Phish #{track.show.date} #{track.title}.mp3",
      length: track.audio_file.size
  end

  def show
    @show ||= Show.find_by(date: params[:date])
  end

  def track
    @track ||=
      Track.includes(show: :venue)
           .find_by(id: params[:id])
  end
end
