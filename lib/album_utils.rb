module AlbumUtils
  
  ######
  # Methods for handling status-checking and creation of albums
  # Albums are zipfiles containing id3-tagged and ordered tracks
  ######
  
  protected
  
  # Check the status of album creation, spawning a new job if required
  # Return a hash including status and url of download if complete
  def album_status(tracks, album_name, is_custom_playlist=false)
    checksum = album_checksum(tracks, album_name)
    album = Album.find_by_md5(checksum)
    if album
      album.update_attributes(:updated_at => Time.now)
      if album.completed_at
        status = 'Ready'
      else
        status = 'Processing'
      end
    else
      status = 'Enqueuing'
      album = Album.create(:name => album_name, :md5 => checksum, :is_custom_playlist => is_custom_playlist)
      # Create zipfile asynchronously using resque
      Resque.enqueue(AlbumCreator, album.id, tracks.map(&:id))
    end
    { :status => status, :url => "/download/#{checksum}" }
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