# frozen_string_literal: true
class DownloadsController < ApplicationController
  def track_info # rubocop:disable Metrics/AbcSize
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
      liked: liked
    }
  end

  def download_track
    raise ActiveRecord::RecordNotFound unless file_exists?
    send_audio_file
  end

  private

  def send_audio_file
    send_file(
      track.audio_file.path,
      type: 'audio/mpeg',
      disposition: 'attachment',
      filename: "Phish #{track.show.date} #{track.title}.mp3",
      length: File.size(track.audio_file.path)
    )
  end

  def file_exists?
    File.exist?(track.audio_file.path)
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
