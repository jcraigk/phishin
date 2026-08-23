require "json"

# Finds tracks whose mp3 carries encoder padding that no decoder can strip.
#
# A LAME-encoded file declares its encoder delay and end padding in the LAME
# extension of the Xing header, and every player drops those samples. Logic
# Pro's mp3 export writes a Xing header WITHOUT that extension, so the padding
# stays in the file as ordinary near-silence: inaudible on its own, but a
# dropout of 10-70ms whenever the next track follows it.
#
# Logic itself compensates when re-importing its own export, which is why the
# files sound seamless there and gap everywhere else.
#
# The header is enough to identify a candidate, so the scan reads only the
# first chunk of each file rather than decoding it. Pass DECODE=1 to also
# measure the actual edge silence, which is slower but says how bad each one is.
module GaplessScan
  # The Xing/Info frame and any LAME extension sit within the first frames of
  # the file, well inside this.
  HEADER_BYTES = 256 * 1024
  # Below this level the samples are encoder padding rather than performance.
  # Measured ramps run 1-34 and the music above them starts in the thousands, so
  # anything in the low hundreds separates them; 20 lands inside the ramp.
  SILENCE_LEVEL = 50
  # Shorter than this is not worth reporting; longer is a real fade, not padding.
  MIN_SILENCE_S = 0.004
  MAX_SILENCE_S = 0.150
  # Padding ends in a cliff: the music runs at full level right up to where the
  # silence starts. A track that fades out decays into it instead, and cutting
  # there would take the fade with it. Measured over this much audio before the
  # silent run, a cliff holds a level a fade has already dropped below.
  CLIFF_WINDOW_S = 0.100
  CLIFF_LEVEL = 300
  REPORT = Rails.root.join("data/gapless_scan/report.json")
  HEADERS = [
    "Date", "Set", "Pos", "Title", "Mid-set", "Head silence (ms)",
    "Tail silence (ms)", "Tail shape", "Action", "URL"
  ].freeze

  # What to do with each track. Only a mid-set tail that ends in a cliff is
  # safe to cut: a set's last track fades on purpose, and a decay is the
  # performance ending rather than encoder padding.
  def self.action_for(row, decode)
    return "trim head (tail unmeasured)" unless decode
    head = row["head_silence_s"].to_f.positive?
    tail = row["tail_silence_s"].to_f.positive? && row["tail_is_padding"]
    return "trim head + tail" if head && tail && row["mid_set"]
    return "trim head" if head
    return "trim tail" if tail && row["mid_set"]
    "no trim needed"
  end

  def self.sheet_rows(found, decode)
    found.map do |row|
      [
        row["date"], row["set"], row["position"], row["title"],
        row["mid_set"] ? "yes" : "no",
        decode ? (row["head_silence_s"].to_f * 1000).round(1) : "",
        decode ? (row["tail_silence_s"].to_f * 1000).round(1) : "",
        if decode
          row["tail_silence_s"].to_f.positive? ? (row["tail_is_padding"] ? "cliff" : "fade") : ""
        else
          ""
        end,
        action_for(row, decode),
        row["url"]
      ]
    end
  end

  # True when the file declares a Xing header but no LAME extension to say how
  # much of it is padding.
  def self.undeclared_padding?(head)
    head.include?("Xing") && !head.include?("LAME")
  end

  def self.head_bytes(track)
    io = track.mp3_audio.blob.service.download_chunk(
      track.mp3_audio.blob.key, 0...HEADER_BYTES
    )
    io.to_s.force_encoding(Encoding::BINARY)
  rescue StandardError
    nil
  end

  # Seconds of near-silence at each edge, plus whether the tail is a cliff.
  def self.edges(path)
    tail, cliff = tail_silence(path)
    [ head_silence(path), tail, cliff ]
  end

  # True when another track follows this one in the same set, which is where a
  # dropout is actually heard. A set's last track runs into applause or a break,
  # so its tail matters far less.
  def self.mid_set?(track)
    track.show.tracks.any? do |other|
      other.set == track.set && other.position == track.position + 1
    end
  end

  def self.head_silence(path)
    pcm = decode(path, [ "-t", format("%.4f", MAX_SILENCE_S + 0.1) ])
    quiet = pcm.take_while { it.abs < SILENCE_LEVEL }.size / 2
    bounded(quiet / 44_100.0)
  end

  # Trailing silence, and whether the audio before it ends in a cliff (encoder
  # padding, safe to cut) or a decay (a real fade, which must be kept).
  def self.tail_silence(path)
    pcm = decode(path, [], pre: [ "-sseof", "-0.50" ])
    return [ 0.0, false ] if pcm.empty?
    quiet = pcm.reverse.take_while { it.abs < SILENCE_LEVEL }.size / 2
    seconds = bounded(quiet / 44_100.0)
    return [ 0.0, false ] if seconds.zero?
    window = (CLIFF_WINDOW_S * 44_100).ceil * 2
    before = pcm.first([ pcm.size - quiet * 2, 0 ].max).last(window)
    [ seconds, before.any? && before.max { |a, b| a.abs <=> b.abs }.abs >= CLIFF_LEVEL ]
  end

  def self.bounded(seconds)
    return 0.0 if seconds < MIN_SILENCE_S || seconds > MAX_SILENCE_S
    seconds.round(4)
  end

  def self.decode(path, post, pre: [])
    out, _err, status = Open3.capture3(
      "ffmpeg", "-v", "error", *pre, "-i", path.to_s, *post,
      "-f", "s16le", "-acodec", "pcm_s16le", "-ar", "44100", "-"
    )
    status.success? ? out.unpack("s<*") : []
  end
end

namespace :gapless_scan do
  desc "Find tracks whose mp3 carries undeclared encoder padding " \
       "(rake gapless_scan:run); DECODE=1 also measures each edge, " \
       "FROM/TO=YYYY-MM-DD scope by show date, LIMIT=n stops early, " \
       "SHEET_ID=<id> appends the report to a Google Sheet"
  task run: :environment do
    decode = ENV["DECODE"] == "1"
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
    puts "Scanning #{total} track(s)#{' with edge measurement' if decode}...\n\n"

    found = []
    checked = 0
    unreadable = 0

    scope.find_each.with_index do |track, i|
      break if limit && i >= limit
      checked += 1
      head = GaplessScan.head_bytes(track)
      if head.nil?
        unreadable += 1
        next
      end
      next unless GaplessScan.undeclared_padding?(head)

      row = {
        "track_id" => track.id, "date" => track.show.date.to_s,
        "position" => track.position, "title" => track.title,
        "url" => track.url
      }
      row["set"] = track.set
      row["mid_set"] = GaplessScan.mid_set?(track)
      if decode
        file = Tempfile.new([ "gapless_#{track.id}", ".mp3" ], binmode: true)
        begin
          track.mp3_audio.blob.download { |chunk| file.write(chunk) }
          file.flush
          head_s, tail_s, cliff = GaplessScan.edges(file.path)
          row["head_silence_s"] = head_s
          row["tail_silence_s"] = tail_s
          # Only a cliff tail is padding; a decay is the performance ending.
          row["tail_is_padding"] = cliff
        ensure
          file.close!
        end
      end
      found << row
      detail =
        if decode
          " (head #{(row['head_silence_s'] * 1000).round}ms, " \
            "tail #{(row['tail_silence_s'] * 1000).round}ms" \
            "#{row['tail_is_padding'] ? ' cliff' : ' fade'})"
        end
      puts "  #{row['date']} t#{row['position']}#{' *' if row['mid_set']}  " \
           "#{row['title']}#{detail}"
      $stdout.flush
      puts "  ...#{checked} checked, #{found.size} found" if (checked % 2_000).zero?
    end

    # find_each walks by id; the report reads better in playing order.
    found.sort_by! { [ it["date"], it["position"] ] }
    FileUtils.mkdir_p(GaplessScan::REPORT.dirname)
    GaplessScan::REPORT.write(JSON.pretty_generate(
      "scanned" => checked, "found" => found.size, "tracks" => found
    ))

    puts "\n#{found.size} of #{checked} track(s) carry undeclared padding"
    puts "#{unreadable} track(s) could not be read" if unreadable.positive?
    mid = found.count { it["mid_set"] }
    puts "#{mid} are mid-set (another track follows) - where gapless is heard"
    if decode
      cliffs = found.count { it["mid_set"] && it["tail_is_padding"] }
      puts "#{cliffs} of those end in a cliff, so the tail is safe to trim"
    end
    by_year = found.group_by { it["date"][0, 4] }.transform_values(&:size)
    by_year.sort.each { |year, n| puts "  #{year}: #{n}" }
    puts "\nReport: #{GaplessScan::REPORT}"

    if ENV["SHEET_ID"].present? && found.any?
      rows = [ GaplessScan::HEADERS ] + GaplessScan.sheet_rows(found, decode)
      GoogleSpreadsheetAppender.call(
        ENV.fetch("SHEET_ID"), ENV.fetch("SHEET_RANGE", "Sheet1!A1"), rows
      )
      puts "Appended #{rows.size - 1} row(s) to spreadsheet #{ENV.fetch('SHEET_ID')}"
    end
  end
end
