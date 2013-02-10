namespace :tracks do

  desc "Set default ID3 tags on all Tracks' audio_files"
  task :save_default_id3 => :environment do
    tracks = Track.all
    tracks.each_with_index do |track, i|
      p "#{i+1} of #{tracks.size} (#{track.title} - id #{track.id})"
      track.save_default_id3_tags
    end
  end
  
  desc "Remove all Intro tracks and re-order tracks in that show"
  task :remove_intros => :environment do
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
