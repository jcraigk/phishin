class DownloadsController < ApplicationController
  def download_track
    raise ActiveRecord::RecordNotFound if track&.audio_file.blank?
    send_audio_file
  end

  private

  def send_audio_file
    send_file(
      track.audio_file.to_io.path,
      type: "audio/mpeg",
      disposition: "attachment",
      filename: "Phish #{track.show.date} #{track.title}.mp3",
      length: track.audio_file.size
    )
  end

  def track
    @track ||=
      Track.includes(show: :venue)
           .find_by(id: params[:id])
  end
end
