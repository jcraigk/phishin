namespace :tracks do
  
  # Create track slugs (then run uniquify_slugs below)
  task create_slugs: :environment do
    Track.all.each do |track|
      track.slug = track.generic_slug
      # handle abbreviations
      track.slug.gsub!(/hold\-your\-head\-up/, 'postgres')
      track.slug.gsub!(/the\-man\-who\-stepped\-into\-yesterday/, 'tmwsiy')
      track.slug.gsub!(/she\-caught\-the\-katy\-and\-left\-me\-a\-mule\-to\-ride/, 'she-caught-the-katy')
      track.slug.gsub!(/mcgrupp\-and\-the\-watchful\-hosemasters/, 'mcgrupp')
      track.slug.gsub!(/big\-black\-furry\-creature\-from\-mars/, 'bbfcfm')
      track.save!
      puts "#{track.title} :: #{track.slug}"
    end
  end
  
  # Uniquify track slugs
  task uniquify_slugs: :environment do
    Show.order('date desc').each do |show|
      puts "Working: #{show.date}"
      tracks = show.tracks.order('position asc').all
      # tracks = Track.where('show_id = 163').all
      tracks.each do |track|
        track.save!
        dupes = []
        tracks.each { |track2| dupes << track2 if track.id != track2.id and track.slug == track2.slug }
        if dupes.size > 0
          num = 2
          dupes.each do |track|
            new_slug = "#{track.slug}-#{num}"
            puts "converting #{track.slug} to #{new_slug}"
            track.slug = new_slug
            track.save!
            num += 1
          end
        end
      end
    end
  end
  
  # Tighten up positions
  task tighten_positions: :environment do
    Show.order('date desc').each do |show|
      puts "Tightening: #{show.date}"
      show.tracks.order('position asc').each_with_index do |track, idx|
        # puts "#{idx+1} for #{track.title} (was #{track.position})"
        track.update_attributes(position: (idx+1))
      end
    end
  end
  
  # Label sets
  task label_null_sets: :environment do
    tracks = Track.where("set IS NULL").order(:position)
    unknown = 0
    set = ''
    for track in tracks
      filename = track.audio_file_file_name
      if filename[0..3] == "II-e"
        set = 'E'
      elsif filename[0..6] == "(Check)"
        set = 'S'
      elsif filename[0..2] == "III"
        set = '3'
      elsif filename[0..1] == "II"
        set = '2'
      elsif filename[0] == "I"
        set = '1'
      else
        set = ''
        unknown += 1
      end
      if set != ''
        track.set = set
        track.save
      end
      puts "#{track.id} :: #{track.show.date} #{track.title} :: #{set}"
    end
    puts "#{unknown} unknowns"
  end
  
  # Rename mp3s from old paperclips names
  # Rename from hash to id, move up a directory (out of "/original")
  desc "Rename mp3s pulled from phishtracks.net"
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
          # puts "Move #{File.basename(f)} => ../#{new_filename}"
          FileUtils.mv(f, new_path)
          FileUtils.rm_rf(old_path)
        end
      elsif File.directory?(f)
        h[f] = traverse_and_rename(f)
      end
    end
  end
  task rename_phishtracks_mp3s: :environment do
    puts "this isn't needed anymore"
    # traverse_and_rename "/var/www/app_content/phishin/tracks"
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
