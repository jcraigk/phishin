namespace :tracks do
  
  # Rename mp3s from old paperclips names
  # Rename from hash to id, move up a directory (out of "/original")
  desc "Rename mp3s"
  def traverse_and_rename(path)
    require 'fileutils'
    Dir.glob("#{path}/*").each_with_object({}) do |f, h|
      if File.file?(f)
        old_path = File.dirname(f)
        path_segments = old_path.split("/")
        if (path_segments.last == "original")
          id = Integer(path_segments[7] + path_segments[8] + path_segments[9], 10)
          path_segments.pop
          new_filename = id.to_s + File.extname(f)
          new_path = path_segments.join("/") + "/" + new_filename
          puts "Move #{File.basename(f)} => ../#{new_filename}"
          FileUtils.mv(f, new_path)
          FileUtils.rm_rf(old_path)
        end
      elsif File.directory?(f)
        h[f] = traverse_and_rename(f)
      end
    end
  end
  task rename_audio_files: :environment do
    traverse_and_rename "/var/www/app_content/phishin/tracks"
  end
  
  desc "Find tracks that don't have valid show associations"
  task find_dangling: :environment do
    track_list = []
    tracks = Track.all
    tracks.each do |track|
      track_list << track unless track.show 
    end
    track_list.each do |track|
      puts "#{track.title} :: #{track.id}"
    end
  end

  desc "Set default ID3 tags on all Tracks' audio_files"
  task save_default_id3: :environment do
    tracks = Track.all
    tracks.each_with_index do |track, i|
      p "#{i+1} of #{tracks.size} (#{track.title} - id #{track.id})"
      track.save_default_id3_tags
    end
  end
  
  desc "Remove all Intro tracks and re-order tracks in that show"
  task remove_intros: :environment do
    tracks = Song.find_by_title("Intro").tracks
    puts "Found #{tracks.size} Intros"
    tracks.each do |track|
      show = track.show
      puts "Removing from #{show.date}"
      track.destroy
      show.tracks.order(:position).each_with_index do |t, i|
        t.position = i + 1
        t.save
        t.save_default_id3_tags
      end
    end
  end
    
end
