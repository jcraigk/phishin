namespace :diag do
  desc "Report the audio blob history for a track (rake diag:blobs[10584])"
  task :blobs, [ :track_id ] => :environment do |_t, args|
    abort "Usage: rake diag:blobs[TRACK_ID]" unless args[:track_id]
    track = Track.find(args[:track_id])
    puts "track #{track.id}  #{track.show.date}  pos #{track.position}  #{track.title.inspect}"
    puts "  duration column: #{track.duration} ms"
    puts

    blob = track.mp3_audio.blob
    puts "current blob:"
    puts "  key:        #{blob.key}"
    puts "  byte_size:  #{blob.byte_size}"
    puts "  checksum:   #{blob.checksum}"
    puts "  created_at: #{blob.created_at}"
    puts "  metadata:   #{blob.metadata.inspect}"
    path = ActiveStorage::Blob.service.path_for(blob.key)
    puts "  on disk:    #{File.exist?(path)} (#{File.size(path) rescue 'n/a'} bytes) #{path}"
    puts

    puts "every attachment ever recorded for this track:"
    ActiveStorage::Attachment.where(record_type: "Track", record_id: track.id)
                             .order(:created_at).each do |att|
      b = att.blob
      puts "  #{att.created_at}  name=#{att.name}  blob=#{b.key}  " \
           "#{b.byte_size} bytes  dur=#{b.metadata[:duration]}"
    end
  end
end
