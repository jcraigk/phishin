namespace :diag do
  desc "Print what the running container actually executes (rake diag:version)"
  task version: :environment do
    puts "GIT_REV:      #{ENV['GIT_REV'] || '(unset)'}"
    puts "FADE_S:       #{TrackMergeService::FADE_S}"
    puts "FADE_RATIO:   #{TrackMergeService::FADE_RATIO}"
    puts "TAIL_TRIM_S:  #{TrackMergeService::TAIL_TRIM_S}"
    puts "MAX_TRIM_S:   #{TrackMergeService::MAX_TRIM_S}"
    puts "ffmpeg:       #{`ffmpeg -version 2>/dev/null`.lines.first.to_s.strip}"
    lame = `lame --version 2>/dev/null`.lines.first.to_s.strip
    puts "lame:         #{lame.presence || 'ABSENT'}"
    # Read from the loaded class, not the source file: a freshly built image can
    # contain code the serving container has not picked up yet.
    src = TrackMergeService.instance_method(:render_merged).source_location.first
    body = File.read(src)
    %w[acrossfade afade=t=in trim_point burst?].each do |token|
      puts format("%-14s %s", "#{token}:", body.include?(token) ? "present" : "ABSENT")
    end
    # The three-track merge runs as one ffmpeg pass; two passes tagged the
    # intermediate on the way through and padded the joint. Asks the loaded
    # class whether it accepts a third part at all.
    accepts_third = TrackMergeService.dry_initializer.options.any? { it.source == :third }
    puts format("%-14s %s", "third option:", accepts_third ? "present" : "ABSENT")
    puts format("%-14s %s", "one-pass:", body.include?("trim_plan") ? "present" : "ABSENT")
  end

  desc "Report whether Google Sheets credentials are usable (rake diag:sheets)"
  task sheets: :environment do
    creds = JSON.parse(ENV.fetch("GOOGLE_SPREADSHEET_CREDS", "{}"))
    puts "creds present: #{creds.any?}"
    puts "keys:          #{creds.keys.sort.join(', ')}" if creds.any?
    puts "scope:         #{creds['scope'] || '(not recorded)'}"
    puts "client_id set: #{creds['client_id'].present?}"
    puts "refresh_token: #{creds['refresh_token'].present?}"
  end

  desc "Measure one track's edges on this container (rake diag:edges TRACK=<id>)"
  task edges: :environment do
    load Rails.root.join("lib/tasks/gapless_scan.rake").to_s
    track = Track.find(ENV.fetch("TRACK"))
    file = Tempfile.new([ "diag", ".mp3" ], binmode: true)
    track.mp3_audio.blob.download { |chunk| file.write(chunk) }
    file.flush
    puts "track:  #{track.show.date} t#{track.position} #{track.title}"
    puts "rate:   #{GaplessScan.sample_rate(file.path)}"
    puts "zeros:  #{(GaplessScan.tail_zeros_s(file.path) * 1000).round(2)} ms"
    puts "head:   #{(GaplessScan.head_silence(file.path) * 1000).round(2)} ms"
    cut = GaplessScan.head_plateau_s(file.path)
    puts "cut:    #{cut ? "#{(cut * 1000).round(2)} ms" : 'NONE'}"
    puts "ffmpeg: #{`ffmpeg -version 2>/dev/null`.lines.first.to_s.strip}"
  ensure
    file&.close!
  end

  desc "Check a proposed tail cut against the decoder (rake diag:verify_cut TRACK=<id> TAIL=<s>)"
  task verify_cut: :environment do
    load Rails.root.join("lib/tasks/gapless_scan.rake").to_s
    track = Track.find(ENV.fetch("TRACK"))
    tail = ENV.fetch("TAIL").to_f
    file = Tempfile.new([ "vc", ".mp3" ], binmode: true)
    track.mp3_audio.blob.download { |chunk| file.write(chunk) }
    file.flush
    rate = GaplessScan.sample_rate(file.path)
    pcm = GaplessScan.decode(file.path, [], pre: [ "-sseof", "-1.00" ])
    frames = pcm.each_slice(2).map { it.map(&:abs).max }
    cut_frames = (tail * rate).round
    kept = frames.first([ frames.size - cut_frames, 0 ].max)
    puts "track:      #{track.show.date} t#{track.position} #{track.title}"
    puts "rate:       #{rate}"
    puts "proposed:   #{(tail * 1000).round(2)} ms"
    puts "last 10 frames that would be REMOVED: #{frames.last(cut_frames).first(10).inspect}"
    puts "max level in removed region: #{frames.last(cut_frames).max}"
    puts "last 10 frames that would be KEPT:    #{kept.last(10).inspect}"
  ensure
    file&.close!
  end
end
