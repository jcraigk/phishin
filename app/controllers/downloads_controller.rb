class DownloadsController < ApplicationController
  
  before_filter :authorize_user!

  # Provide a track as a downloadable MP3
  def download_track
    track = Track.find(params[:track_id])
    redirect_to(:root, alert: 'The requested file could not be found') and return unless File.exists?(track.audio_file.path)
    send_file track.audio_file.path, :type => "audio/mpeg", :disposition => "attachment", :filename => "Phish #{track.show.date} #{track.title}.mp3", :length => File.size(track.audio_file.path)
  end
  
  # Respond to an AJAX request to create/fetch an album
  def request_download_show
    if show = Show.where(date: params[:date]).first
      album_tracks = show.tracks.order(:position).all
      # Prune away tracks if specific set is being called
      if params[:set].present? and show.tracks.map(&:set).include? params[:set]
        # If the last set of the show is being requested, include encore tracks
        album_tracks.reject! { |track| /^E\d?$/.match track.set } unless show.last_set == params[:set].to_i
        album_tracks.reject! { |track| /^\d$/.match track.set and track.set != params[:set] }
        album_name = "#{show.date.to_s} #{album_tracks.first.set_name}" if album_tracks.any?
      else
        album_name = show.date.to_s
      end
      if album_tracks.any?
        render :json => album_status(album_tracks, album_name)
      else
        render :json => { :status => "Invalid download request" }
      end
    else
      render :json => { :status => "Invalid show" }
    end
  end
  
  # Provide a downloadable album that has already been created
  def download_album
    if album = Album.find_by_md5(params[:md5])
      if album.completed_at and File.exists? album.zip_file.path
        send_file album.zip_file.path, :type => album.zip_file.content_type, :disposition => "attachment", :filename => "Phish - #{album.name}", :length => album.zip_file.size
      elsif album.error_at
        render :text => "This download is not available because an error occurred while processing it"
      else
        render :text => "This download is still being processed...please try again later"
      end
    else
      render :text => "Invalid download request"
    end
  end

  private
  
  def authorize_user!
    redirect_to(:root, alert: 'You must be signed in to download tracks') and return unless current_user or request.xhr?
  end
  
  # Check the status of album creation, spawning a new job if required
  # Return a hash including status and url of download if complete
  def album_status(tracks, album_name, is_custom_playlist=false)
    checksum = album_checksum(tracks, album_name)
    album = Album.find_by_md5(checksum)
    if album
      album.update_attributes(:updated_at => Time.now)
      if album.completed_at
        status = 'Ready'
      elsif album.error_at
        status = 'Error'
      else
        # If the album is older than our timeout, provide error and alternate link
        if Time.now - album.created_at > ALBUM_TIMEOUT
          status = 'Timeout'
        else
          status = 'Processing'
        end
      end
    else
      status = 'Enqueuing'
      album = Album.create(:name => album_name, :md5 => checksum, :is_custom_playlist => is_custom_playlist)
      # Create zipfile asynchronously using resque
      Resque.enqueue(AlbumCreator, album.id, tracks.map(&:id))
    end
    { :status => status, :url => download_album_path(album.md5) }
  end
  
  # Generate an MD5 checksum of an album using its tracks' audio_file paths and album_name
  # Album_name will differentiate two identical playlists with different names (for unique id3 tagging)
  def album_checksum(tracks, album_name)
    digest = Digest::MD5.new()
    tracks.each { |track| digest << track.audio_file.path }
    digest << album_name
    digest.to_s
  end

end