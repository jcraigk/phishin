namespace :diag do
  desc "Report what the second pass of a three-track merge sees (rake diag:pass2[10584])"
  task :pass2, [ :track_id ] => :environment do |_t, args|
    track = Track.find(args[:track_id])
    svc = TrackMergeService.allocate
    file = Tempfile.new([ "diag", ".mp3" ], binmode: true)
    track.mp3_audio.blob.download { |chunk| file.write(chunk) }
    file.flush
    puts "track #{track.id} #{track.title.inspect}"
    puts "  blob key:        #{track.mp3_audio.blob.key}"
    puts "  blob bytes:      #{track.mp3_audio.blob.byte_size}"
    puts "  duration column: #{track.duration} ms"
    puts "  decoded length:  #{svc.send(:decoded_duration_s, file.path)}"
    puts "  tail_burst?:     #{svc.send(:tail_burst?, file.path)}"
    puts "  head_burst?:     #{svc.send(:head_burst?, file.path)}"
    out, = Open3.capture3("ffmpeg", "-v", "error", "-sseof", "-0.50", "-i", file.path,
                          "-f", "s16le", "-acodec", "pcm_s16le", "-ar", "44100", "-")
    s = out.unpack("s<*")
    edge = s.last((0.005 * 44_100).ceil * 2)
    rest = s.first([ s.size - edge.size, 0 ].max)
    body = rest.last((0.5 * 44_100).ceil * 2)
    puts "  tail edge peak:  #{edge.map(&:abs).max}"
    puts "  tail body peak:  #{body.map(&:abs).max}" if body.any?
  ensure
    file&.close!
  end
end
