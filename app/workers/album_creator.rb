class AlbumCreator
  
  @queue = :albums_queue
  
  require 'taglib'
  
  # Create a zipped album from a set of tracks
  # Set id3 tags in the process for context of this album
  def self.perform(album_id, track_ids)
    all_files_present = true
    album = Album.find(album_id)
    tracks = []
    track_ids.each { |id| tracks << Track.find(id) }
    tmpdir = "#{TMP_PATH}album_#{album.md5}/"
    # FileUtils.rm_rf tmpdir
    Dir.mkdir tmpdir
    tracks.each_with_index do |track, i|
      tmpfile_path = tmpdir + ((tracks.size >= 100) ? "%03d" : "%02d" % (i + 1)) + " - " + track.title.gsub(/[^0-9A-Za-z.\-\s]/, '_') + ".mp3"
      puts track.audio_file.path
      if !File.exists?(track.audio_file.path)
        all_files_present = false
      elsif all_files_present
        FileUtils.cp track.audio_file.path, tmpfile_path
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
        
            # Commented out => don't change the defaults (as set by rake tracks:save_default_id3)
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
    end
      
    unless all_files_present
      album.update_attributes(error_at: Time.now)
      puts "ERROR"
    else
        
      # Remove existing albums if not enough free space in cache for new uncompressed album
      new_album_size = 0
      tracks.map { |track| new_album_size += track.audio_file.size}
      while ALBUM_CACHE_MAX_SIZE - Album.cache_used < new_album_size do
        Album.completed.order(:updated_at).first.destroy
      end
    
      # Create zipfile in working directory and apply as paperclip attachment to album
      tmpfile = "#{tmpdir}#{album.md5}.zip"
      system "cd #{tmpdir} && zip -r0 #{tmpfile} ./*"
      album.zip_file = File.open tmpfile
    
      # Set album as completed
      album.update_attributes(:completed_at => Time.now)
      
      puts "SUCCESS"
        
    end
      
    # Delete temporary working directory
    FileUtils.rm_rf tmpdir
    
  end

end