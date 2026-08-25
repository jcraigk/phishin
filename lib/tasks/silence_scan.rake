require "json"

# Finds tracks that end in a long run of digital silence.
#
# When a split drops the audio at the end of a track and pads the length back
# out, what is left is exact zeros - not the decaying near-silence an encoder
# writes, but samples that are literally zero, for hundreds of milliseconds.
# 2021-10-24 L.A. Woman is the case this was built from: 628ms of zeros
# standing in for 0.55s of music the split lost.
#
# This is a different fault from the one gapless_scan looks for. Encoder
# padding is inaudible material that should be trimmed; this is missing audio,
# and trimming the silence would not bring it back. Repair needs the original
# source, so this only reports.
#
# Only the tail matters, so the scan reads the last chunk of each file rather
# than the whole thing - mp3 frames are self contained, so a byte range off the
# end decodes on its own.
module SilenceScan
  # Enough of the end to decode about a second of audio at any bitrate the
  # catalog uses, and enough to hold a run far longer than anything reportable.
  TAIL_BYTES = 64 * 1024
  # An encoder writes at most a few tens of milliseconds of padding. Measured
  # across the catalog, real tracks sit under 50ms and faults sit above 400ms,
  # with nothing in between, so this threshold falls in an empty band rather
  # than through a cluster.
  SUSPECT_S = 0.150
  CHANNELS_PER_FRAME = 2
  BYTES_PER_SAMPLE = 2

  def self.report_path
    dir = ENV["OUT"].presence
    return Pathname.new(dir).join("split_report.json") if dir
    Rails.root.join("data/split_scan/report.json")
  end

  # Seconds of exact digital zero at the end of the given mp3 bytes.
  #
  # Zero rather than "quiet": encoder padding decays through low values and
  # would be caught by a threshold, while a split that lost its audio leaves
  # samples that are exactly zero.
  def self.trailing_zeros_s(bytes)
    pcm, rate = decode(bytes)
    return nil if pcm.nil? || pcm.empty?
    frames = pcm.each_slice(CHANNELS_PER_FRAME).map { it.map(&:abs).max }
    zeros = 0
    frames.reverse_each do |level|
      break unless level.zero?
      zeros += 1
    end
    # Every frame decoded was silent, so the run starts before what was read
    # and this is a floor rather than a measurement. Reporting it would understate
    # the fault, and the caller cannot tell the difference.
    return nil if zeros == frames.size
    (zeros / rate.to_f).round(4)
  end

  def self.suspect?(seconds)
    seconds.present? && seconds >= SUSPECT_S
  end

  def self.decode(bytes)
    Tempfile.create([ "split_tail", ".mp3" ], binmode: true) do |file|
      file.write(bytes)
      file.flush
      rate = sample_rate(file.path)
      out, _err, status = Open3.capture3(
        "ffmpeg", "-v", "error", "-i", file.path,
        "-f", "s16le", "-acodec", "pcm_s16le", "-"
      )
      return [ nil, nil ] unless status.success? && !out.empty?
      [ out.unpack("s<*"), rate ]
    end
  end

  def self.sample_rate(path)
    out, _err, status = Open3.capture3(
      "ffprobe", "-v", "error", "-select_streams", "a:0",
      "-show_entries", "stream=sample_rate", "-of", "default=nw=1:nk=1", path
    )
    rate = out.to_s.strip.to_i
    status.success? && rate.positive? ? rate : 44_100
  end

  def self.tail_bytes(track)
    blob = track.mp3_audio.blob
    size = blob.byte_size.to_i
    return nil unless size.positive?
    start = [ size - TAIL_BYTES, 0 ].max
    blob.service.download_chunk(blob.key, start...size).to_s.force_encoding(Encoding::BINARY)
  rescue StandardError
    nil
  end

  # A run of silence closing a set is unremarkable - the recording just ends.
  # Mid set it means the next track starts somewhere the audio does not reach.
  def self.followed_in_set?(track)
    track.show.tracks.any? do |other|
      other.set == track.set && other.position == track.position + 1
    end
  end
end

namespace :silence_scan do
  desc "Find tracks ending in digital silence a split left behind " \
       "(rake silence_scan:run); FROM/TO=YYYY-MM-DD scope by show date, " \
       "LIMIT=n stops early, OUT=<dir> writes the report elsewhere"
  task run: :environment do
    limit = ENV["LIMIT"].presence&.to_i
    scope = Track.where.not(audio_status: "missing")
                 .includes(:show, mp3_audio_attachment: :blob)
    if ENV["FROM"].present? || ENV["TO"].present?
      from = ENV["FROM"].presence || "1900-01-01"
      to = ENV["TO"].presence || "2999-12-31"
      scope = scope.joins(:show).where(shows: { date: from..to })
      puts "Scoped to shows #{from}..#{to}"
    end
    total = limit || scope.count
    puts "Scanning #{total} track(s) for split silence...\n\n"

    found = []
    checked = 0
    unreadable = 0

    scope.find_each.with_index do |track, i|
      break if limit && i >= limit
      checked += 1
      bytes = SilenceScan.tail_bytes(track)
      if bytes.nil?
        unreadable += 1
        next
      end
      seconds = SilenceScan.trailing_zeros_s(bytes)
      next unless SilenceScan.suspect?(seconds)

      row = {
        "track_id" => track.id, "date" => track.show.date.to_s,
        "position" => track.position, "title" => track.title,
        "set" => track.set, "url" => track.url,
        "mp3_url" => track.mp3_url,
        "duration_s" => (track.duration.to_i / 1000.0).round(3),
        "trailing_zeros_s" => seconds,
        "followed_in_set" => SilenceScan.followed_in_set?(track)
      }
      found << row
      puts format("%-11s t%-3d %-40s %8.1fms%s",
                  row["date"], row["position"], row["title"].to_s.first(40),
                  seconds * 1000, row["followed_in_set"] ? "  (mid set)" : "")
      print "\r#{checked}/#{total} scanned..." if (checked % 250).zero?
    end

    path = SilenceScan.report_path
    FileUtils.mkdir_p(path.dirname)
    path.write(JSON.pretty_generate(
      "scanned" => checked, "found" => found.size, "tracks" => found
    ))

    mid_set = found.count { it["followed_in_set"] }
    puts "\n\nScanned #{checked} track(s), #{unreadable} unreadable"
    puts "Found #{found.size}, of which #{mid_set} sit mid set (lost audio)"
    puts "Report: #{path}"
  end

  desc "Summarize the last split scan report (rake silence_scan:summary)"
  task summary: :environment do
    path = SilenceScan.report_path
    abort "No report at #{path} - run split_scan:run first" unless path.exist?
    rows = JSON.parse(path.read)["tracks"]
    mid = rows.select { it["followed_in_set"] }
    puts "#{rows.size} track(s) end in silence, #{mid.size} of them mid set\n\n"
    mid.group_by { it["date"] }.sort.each do |date, items|
      puts "#{date}  #{items.size} track(s)"
      items.sort_by { it["position"] }.each do |row|
        puts format("   t%-3d %-42s %8.1fms",
                    row["position"], row["title"].to_s.first(42),
                    row["trailing_zeros_s"] * 1000)
      end
    end
  end
end
