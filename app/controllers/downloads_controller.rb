class DownloadsController < ApplicationController
  
  include AlbumUtils
  
  # before_filter :authorize_user!

  # Provide a track as a downloadable MP3
  def download_track
    track = Track.find(params[:track_id])
    redirect_to(:root, alert: 'The requested file could not be found') and return unless File.exists?(track.audio_file.path)
    send_file track.audio_file.path, :type => "audio/mpeg", :disposition => "attachment", :filename => "Phish #{track.show.date} #{track.title}.mp3", :length => File.size(track.audio_file.path)
  end
  
  # Respond to an AJAX request to create an album
  def request_album_download
    if show = Show.where(date: params[:show_id])
      album_tracks = show.tracks.order(:position).all
      # Prune away tracks if specific set is being called
      if params[:set].present? and show.tracks.map(&:set).include? params[:set]
        # If the last set of the show is being requested, include encore tracks
        album_tracks.reject! { |track| /^E\d?$/.match track.set } unless show.last_set == params[:set].to_i
        album_tracks.reject! { |track| /^\d$/.match track.set and track.set != params[:set] }
        album_name = "#{show.show_date.to_s} #{album_tracks.first.set_name}" if album_tracks.any?
      else
        album_name = show.show_date.to_s
      end
      if album_tracks.any?
        render :json => album_status(album_tracks, album_name)
      else
        render :json => { :status => "Invalid album request" }
      end
    else
      render :json => { :status => "Invalid show" }
    end
  end

  
  private
  
  def authorize_user!
    redirecto_to(:root, alert: 'You must be signed in to download tracks') and return unless current_user
  end

end