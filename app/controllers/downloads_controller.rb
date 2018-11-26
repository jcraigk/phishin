# frozen_string_literal: true
class DownloadsController < ApplicationController
  def track_info
    render render json: { success: false } unless track
    render json: {
      success: true,
      id: track.id,
      title: track.title,
      duration: track.duration,
      show: track.show.date.strftime('%Y.%m.%d').to_s,
      show_url: "/#{track.show.date}",
      venue: track.show.venue.name.to_s,
      venue_url: "/#{track.show.venue.slug}",
      city: track.show.venue.location,
      city_url: "/map?map_term=#{CGI.escape(track.show.venue.location)}",
      likes_count: track.likes_count,
      liked: liked
    }
  end

  def download_track
    return redirect_to(:root, alert: 'The file could not be found') unless File.exist?(track.audio_file.path)

    send_file(
      track.audio_file.path,
      type: 'audio/mpeg',
      disposition: 'attachment',
      filename: "Phish #{track.show.date} #{track.title}.mp3",
      length: File.size(track.audio_file.path)
    )
  end

  private

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
