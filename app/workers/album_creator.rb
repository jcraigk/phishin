class AlbumCreator
  
  @queue = :albums_queue
  
  require 'taglib'
  
  # Create a zipped album from a set of tracks
  # Set id3 tags in the process for context of this album
  def self.perform(album_id, track_ids)
    album = Album.find(album_id)
    tracks = []
    track_ids.each { |id| tracks << Track.find(id) }
    tmpdir = "#{TMP_PATH}/album_#{album.md5}/"
    # TODO Remove the rm_rf
    # FileUtils.rm_rf tmpdir
    Dir.mkdir tmpdir
    tracks.each_with_index do |track, i|
      tmpfile_path = tmpdir + ((tracks.size >= 100) ? "%03d" : "%02d" % (i + 1)) + " - " + track.title.gsub(/[^0-9A-Za-z.\-\s]/, '_') + ".mp3"
      FileUtils.cp track.song_file.path, tmpfile_path
      TagLib::MPEG::File.open(tmpfile_path) do |file|
        # Set basic ID3 tags
        tag = file.id3v2_tag
        if tag
          # Add the date/set to the song title if the album is a custom playlist
          if album.is_custom_playlist
            tag.title = "#{track.title} (#{track.show.date} #{track.set_album_abbreviation})"
            tag.album = album.name
          end
          tag.track = i + 1
        
          # Don't change the defaults (as set by rake tracks:save_default_id3)
          # tag.title = track.title
          # tag.artist = "Phish"
          # tag.year = track.show.date.strftime("%Y").to_i
          # tag.genre = "Rock"
          # tag.comment = "Visit phishtracks.net for free Phish audio"
          # Add cover art
          # apic = TagLib::ID3v2::AttachedPictureFrame.new
          # apic.mime_type = "image/jpeg"
          # apic.description = "Cover"
          # apic.type = TagLib::ID3v2::AttachedPictureFrame::FrontCover
          # apic.picture = File.open(Rails.root.to_s + '/app/assets/images/cover_generic.jpg', 'rb') { |f| f.read }
          # tag.add_frame(apic)
        
          # Save
          file.save
        end
      end
    end

    # Remove existing albums if not enough free space in cache for new uncomprssed album
    new_album_size = 0
    tracks.each { |track| new_album_size += track.song_file.size}
    cache_size = 0
    existing_albums = Album.completed.order(:updated_at).all
    existing_albums.each { |album| cache_size += album.zip_file.size }
    existing_albums.size.times { |i| existing_albums.shift.destroy if new_album_size > ALBUM_CACHE_MAX_SIZE - cache_size }
      
    # Create zipfile in working directory and apply as paperclip attachment to album
    tmpfile = "#{tmpdir}#{album.md5}.zip"
    system "cd #{tmpdir} && zip #{tmpfile} ./*"
    album.zip_file = File.open tmpfile
    
    # Delete temporary working directory
    FileUtils.rm_rf tmpdir

    # Set album as completed
    album.update_attributes(:completed_at => Time.now)
    
  end

end