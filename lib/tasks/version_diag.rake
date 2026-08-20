namespace :diag do
  desc "Print what the running container actually executes (rake diag:version)"
  task version: :environment do
    puts "GIT_REV:      #{ENV['GIT_REV'] || '(unset)'}"
    puts "FADE_S:       #{TrackMergeService::FADE_S}"
    puts "FADE_RATIO:   #{TrackMergeService::FADE_RATIO}"
    puts "TAIL_TRIM_S:  #{TrackMergeService::TAIL_TRIM_S}"
    puts "MAX_TRIM_S:   #{TrackMergeService::MAX_TRIM_S}"
    puts "ffmpeg:       #{`ffmpeg -version 2>/dev/null`.lines.first.to_s.strip}"
    # Read from the loaded class, not the source file: a freshly built image can
    # contain code the serving container has not picked up yet.
    src = TrackMergeService.instance_method(:render_merged).source_location.first
    body = File.read(src)
    %w[acrossfade afade=t=in trim_point burst?].each do |token|
      puts format("%-14s %s", "#{token}:", body.include?(token) ? "present" : "ABSENT")
    end
  end
end
