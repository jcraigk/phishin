namespace :diag do
  desc "Check that atrim actually removes the tail burst (rake diag:atrim[/content/import])"
  task :atrim, [ :dir ] => :environment do |_t, args|
    dir = args[:dir] || "/content/import"
    file = Dir.glob("#{dir}/*.mp3").sort.first
    abort "No mp3 in #{dir}" unless file
    puts "ffmpeg: #{`ffmpeg -version 2>/dev/null`.lines.first.to_s.strip}"
    puts "file:   #{File.basename(file)}"

    dur = `ffprobe -v error -show_entries format=duration -of csv=p=0 "#{file}"`.strip.to_f
    finish = dur - TrackMergeService::TAIL_TRIM_S
    out = "/tmp/atrim_out.wav"
    system("ffmpeg", "-y", "-v", "error", "-i", file, "-af",
           "atrim=start=0:end=#{format('%.4f', finish)},asetpts=PTS-STARTPTS," \
           "aresample=44100", "-c:a", "pcm_s16le", out)
    got = `ffprobe -v error -show_entries format=duration -of csv=p=0 #{out}`.strip.to_f

    puts "source duration:  #{dur}"
    puts "atrim end:        #{format('%.4f', finish)}"
    puts "result duration:  #{got}"
    puts "actually trimmed: #{((dur - got) * 1000).round(2)} ms " \
         "(expected ~#{(TrackMergeService::TAIL_TRIM_S * 1000).round})"

    pcm = `ffmpeg -v error -sseof -0.05 -i #{out} -f s16le -acodec pcm_s16le -ar 44100 - 2>/dev/null`
    samples = pcm.unpack("s<*")
    puts "tail peak after trim: #{samples.last(400).map(&:abs).max}  (a burst reads ~30000)"

    svc = TrackMergeService.allocate
    puts "tail_burst? on source: #{svc.send(:tail_burst?, file)}"
  end
end
