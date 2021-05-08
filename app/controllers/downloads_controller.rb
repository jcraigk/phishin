# frozen_string_literal: true
class DownloadsController < ApplicationController
  def track_info # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return render json: { success: false } unless track
    render json: {
      success: true,
      id: track.id,
      title: track.title,
      duration: track.duration,
      show: track.show.date_with_dots,
      show_url: "/#{track.show.date}",
      venue: track.show.venue_name,
      venue_url: "/#{track.show.venue.slug}",
      city: track.show.venue.location,
      city_url: "/map?map_term=#{CGI.escape(track.show.venue.location)}",
      likes_count: track.likes_count,
      liked: liked,
      waveform_image_url: track.waveform_image_url
    }
  end

  def download_track
    raise ActiveRecord::RecordNotFound if track.audio_file.blank?
    send_audio_file
  end

  private

  def send_audio_file
    send_file(
      track.audio_file.to_io.path,
      type: 'audio/mpeg',
      disposition: 'attachment',
      filename: "Phish #{track.show.date} #{track.title}.mp3",
      length: track.audio_file.size
    )
  end

  def track
    @track ||=
      Track.includes(show: :venue)
           .find_by(id: params[:track_id])
  end

  def liked
    @liked ||=
      current_user &&
      track.likes.find_by(user: current_user)
  end
end
