show = Show.find_by(date: '1991-02-16')
puts 'Removing duplicate tracks with missing audio...'

# Get tracks with missing audio that are likely duplicates
tracks_to_remove = []

# Look for tracks that appear to be duplicates based on title and set
track_groups = show.tracks.group_by { |t| [t.title.downcase.strip, t.set] }
track_groups.each do |key, tracks|
  if tracks.count > 1
    # Keep the track with audio if any, otherwise keep the first one
    tracks_with_audio = tracks.select { |t| t.audio_status != 'missing' }
    if tracks_with_audio.any?
      # Remove all missing audio tracks for this title/set combo
      tracks_to_remove += tracks.select { |t| t.audio_status == 'missing' }
    else
      # Keep the first track, remove the rest
      tracks_to_remove += tracks[1..-1]
    end
  end
end

puts "Found #{tracks_to_remove.count} duplicate tracks to remove"
tracks_to_remove.each { |t| puts "  - #{t.title} (Set #{t.set}, Position #{t.position})" }

# Remove the duplicate tracks
tracks_to_remove.each(&:destroy!)
puts "Removed #{tracks_to_remove.count} duplicate tracks"
puts "Remaining tracks: #{show.tracks.reload.count}"
