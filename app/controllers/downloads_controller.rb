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

  # Respond to an AJAX request to create/fetch an album
  def request_download_show
    if (show = Show.where(date: params[:date]).first)
      album_tracks = show.tracks.order(:position).all
      # Prune away tracks if specific set is being called
      if params[:set].present? && show.tracks.map(&:set).include?(params[:set])
        # If the last set of the show is being requested, include encore tracks
        album_tracks.reject! { |track| /\AE\d?\z/.match track.set } unless show.last_set == params[:set].to_i
        album_tracks.reject! { |track| /\A\d\z/.match track.set && track.set != params[:set] }
        album_name = "#{show.date} #{album_tracks.first.set_name}" if album_tracks.any?
      else
        album_name = show.date.to_s
      end
      if album_tracks.any?
        render json: album_status(album_tracks, album_name)
      else
        render json: { status: 'Invalid download request' }
      end
    else
      render json: { status: 'Invalid show' }
    end
  end

  # Provide a downloadable album that has already been created
  def download_album
    if (album = Album.find_by_md5(params[:md5]))
      if album.completed_at.present? && File.exist?(album.zip_file.path)
        log_this_album_request album, 'download'
        send_file(
          album.zip_file.path,
          type: album.zip_file.content_type,
          disposition: 'attachment',
          filename: "Phish - #{album.name}",
          length: album.zip_file.size
        )
      elsif album.error_at
        render text: 'This download is not available because an error occurred while processing it'
      else
        render text: 'This download is still being processed...please try again later'
      end
    else
      render text: 'Invalid download request'
    end
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

  # Check the status of album creation, spawning a new job if required
  # Return a hash including status and url of download if complete
  def album_status(tracks, album_name, is_custom_playlist = false)
    checksum = album_checksum(tracks, album_name)
    if (album = Album.find_by_md5(checksum))
      album.update_attributes(updated_at: Time.now)
      status = if album.completed_at
                 'Ready'
               elsif album.error_at
                 'Error'
               elsif Time.now - album.created_at > ALBUM_TIMEOUT
                 'Timeout'
               else
                 'Processing'
               end
    else
      status = 'Enqueuing'
      album = Album.create(name: album_name, md5: checksum, is_custom_playlist: is_custom_playlist)
      # Create zipfile asynchronously using resque
      # Resque.enqueue(AlbumCreator, album.id, tracks.map(&:id))
      log_this_album_request album, 'request'
    end

    { status: status, url: download_album_path(album.md5) }
  end

  # Generate an MD5 checksum of an album using its tracks' audio_file paths and album_name
  # Album_name will differentiate two identical playlists with different names (for unique id3 tagging)
  def album_checksum(tracks, album_name)
    digest = Digest::MD5.new
    tracks.each { |track| digest << track.audio_file.path }
    digest << album_name
    digest.to_s
  end

  def log_track_request(kind)
    current_user_id = (current_user ? current_user.id : 0)
    TrackRequest.create(track_id: params[:track_id], user_id: current_user_id, kind: kind, created_at: Time.now)
  end

  def log_this_album_request(album, kind)
    current_user_id = (current_user ? current_user.id : 0)
    AlbumRequest.create(
      album_id: album.id,
      user_id: current_user_id,
      name: album.name,
      md5: album.md5,
      kind: kind,
      created_at: Time.now
    )
  end
end
