# frozen_string_literal: true
class DownloadsController < ApplicationController
  before_action :authorize_user!, except: :play_track

  def track_info
    if track
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
    else
      render json: { success: false }
    end
  end

  # Provide a track as a downloadable MP3
  def download_track
    track = Track.find(params[:track_id])
    unless File.exist?(track.audio_file.path)
      redirect_to(:root, alert: 'The requested file could not be found')
      return
    end

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
      Track.where(id: params[:track_id])
           .includes(show: :venue)
           .first
  end

  def liked
    @liked ||=
      current_user &&
      track.likes.where(user: current_user).first.present?
  end

  def authorize_user!
    return if current_user || request.xhr?
    redirect_to :root, alert: 'You must be signed in to download tracks'
  end
end
