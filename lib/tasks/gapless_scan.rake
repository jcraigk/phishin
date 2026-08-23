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
  # A single threshold cannot tell padding from a quiet intro: it measures where
  # the audio first gets loud, which is padding PLUS however long the music takes
  # to rise. Where padding ends at a hard boundary the answer is the same at
  # every threshold, so the edge is measured across a ladder of them and only a
  # stable answer is trusted. Where the answers keep climbing, the quiet is the
  # performance and the track is left for review instead.
  PLATEAU_LADDER = [ 100, 200, 400, 800, 1600 ].freeze
  # Answers this close together are the same boundary; a sample at 44.1kHz is
  # 0.023ms, so this is a couple of frames of slack, not a musical amount.
  PLATEAU_TOLERANCE_S = 0.0015
  # How many rungs must agree before the boundary counts as real.
  PLATEAU_MIN_AGREE = 3
  # Shorter than this is not worth reporting; longer is a real fade, not padding.
  MIN_SILENCE_S = 0.004
  MAX_SILENCE_S = 0.150
  # Padding ends in a cliff: the music runs at full level right up to where the
  # silence starts. A track that fades out decays into it instead, and cutting
  # there would take the fade with it. Measured over this much audio before the
  # silent run, a cliff holds a level a fade has already dropped below.
  CLIFF_WINDOW_S = 0.100
  CLIFF_LEVEL = 300
  # Written under Rails.root by default, which is fine locally but lives in the
  # container's ephemeral filesystem in production and is lost on the next
  # deploy. OUT=/content/import puts it on the persistent volume instead, where
  # it can be fetched over ftp.
  def self.report_path
    dir = ENV["OUT"].presence
    return Pathname.new(dir).join("gapless_report.json") if dir
    Rails.root.join("data/gapless_scan/report.json")
  end

  def self.review_dir
    dir = ENV["OUT"].presence
    return Pathname.new(dir).join("gapless_review") if dir
    Rails.root.join("data/gapless_review")
  end
  HEADERS = [
    "Date", "Set", "Pos", "Title", "Joint before", "Joint after",
    "Head silence (ms)", "Head cut (ms)", "Tail silence (ms)", "Tail shape",
    "Action", "URL"
  ].freeze

  # What to do with each track, scoped to the joints between tracks.
  #
  # A head is only cut when a track precedes this one in the set, and a tail
  # only when one follows AND the audio ends in a cliff rather than a decay.
  # The outer edges of a set are left alone whatever they measure.
  def self.action_for(row, decode)
    return "measure with DECODE=1" unless decode
    # A head is only cut where the thresholds agree where the padding ends.
    # Without that agreement the quiet belongs to the music, so the track is
    # called out for a human rather than trimmed on a guess.
    has_head = row["head_silence_s"].to_f.positive? && row["preceded_in_set"]
    head = has_head && row["head_cut_s"].present?
    tail = row["tail_silence_s"].to_f.positive? &&
           row["tail_is_padding"] && row["followed_in_set"]
    return "trim head + tail" if head && tail
    return "trim head" if head
    return "trim tail" if tail
    return "review head (no plateau)" if has_head
    "no trim needed"
  end

  def self.sheet_rows(found, decode)
    found.map do |row|
      [
        row["date"], row["set"], row["position"], row["title"],
        row["preceded_in_set"] ? "yes" : "no",
        row["followed_in_set"] ? "yes" : "no",
        decode ? (row["head_silence_s"].to_f * 1000).round(1) : "",
        decode && row["head_cut_s"] ? (row["head_cut_s"].to_f * 1000).round(1) : "",
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

  # Seconds of near-silence at each edge, whether the tail is a cliff, and where
  # the head padding provably ends (nil when the thresholds disagree).
  def self.edges(path)
    tail, cliff = tail_silence(path)
    [ head_silence(path), tail, cliff, head_plateau_s(path) ]
  end

  # Each edge is only in scope when there is a joint on that side of it.
  #
  # A set's first track may open with a deliberate fade-in and its last may
  # close with a real fade-out, so those outer edges are left alone: only the
  # joints between tracks within a set are trimmed. Whether padding is present
  # says nothing about whether cutting it is safe - position does.
  def self.followed_in_set?(track)
    neighbor?(track, 1)
  end

  def self.preceded_in_set?(track)
    neighbor?(track, -1)
  end

  def self.neighbor?(track, offset)
    track.show.tracks.any? do |other|
      other.set == track.set && other.position == track.position + offset
    end
  end

  def self.head_silence(path)
    pcm = decode(path, [ "-t", format("%.4f", MAX_SILENCE_S + 0.4) ])
    quiet = pcm.take_while { it.abs < SILENCE_LEVEL }.size / 2
    bounded(quiet / 44_100.0)
  end

  # Where the head padding ends, measured across PLATEAU_LADDER, or nil when the
  # thresholds disagree. Disagreement means the quiet at the head belongs to the
  # music rather than the encoder, and cutting to any one threshold would take
  # part of the performance with it.
  def self.head_plateau_s(path)
    pcm = decode(path, [ "-t", format("%.4f", MAX_SILENCE_S + 0.4) ])
    return nil if pcm.empty?
    answers = PLATEAU_LADDER.map { first_at_or_above(pcm, it) }
    return nil if answers.any?(&:nil?)
    run = longest_agreeing_run(answers)
    return nil if run.size < PLATEAU_MIN_AGREE
    # The earliest point the agreeing thresholds share: the boundary itself,
    # never further into the audio than any one of them reported.
    run.min.round(4)
  end

  def self.first_at_or_above(pcm, level)
    index = pcm.index { it.abs >= level }
    return nil if index.nil?
    index / 2 / 44_100.0
  end

  def self.longest_agreeing_run(answers)
    best = []
    answers.each_index do |i|
      run = [ answers[i] ]
      answers[(i + 1)..].each do |value|
        break if (value - run.first).abs > PLATEAU_TOLERANCE_S
        run << value
      end
      best = run if run.size > best.size
    end
    best
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
        # mp3_url and duration are carried so the review page can render the
        # joint without going back to the API for every track.
        "mp3_url" => track.mp3_url,
        "duration_s" => (track.duration.to_i / 1000.0).round(3),
        "track_id" => track.id, "date" => track.show.date.to_s,
        "position" => track.position, "title" => track.title,
        "url" => track.url
      }
      row["set"] = track.set
      row["preceded_in_set"] = GaplessScan.preceded_in_set?(track)
      row["followed_in_set"] = GaplessScan.followed_in_set?(track)
      if decode
        file = Tempfile.new([ "gapless_#{track.id}", ".mp3" ], binmode: true)
        begin
          track.mp3_audio.blob.download { |chunk| file.write(chunk) }
          file.flush
          head_s, tail_s, cliff, plateau = GaplessScan.edges(file.path)
          row["head_silence_s"] = head_s
          row["tail_silence_s"] = tail_s
          # Only a cliff tail is padding; a decay is the performance ending.
          row["tail_is_padding"] = cliff
          # Present only when every threshold agrees where the padding ends.
          row["head_cut_s"] = plateau
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
      joints = "#{row['preceded_in_set'] ? '<' : ' '}#{row['followed_in_set'] ? '>' : ' '}"
      puts "  #{row['date']} t#{row['position']} #{joints}  " \
           "#{row['title']}#{detail}"
      $stdout.flush
      puts "  ...#{checked} checked, #{found.size} found" if (checked % 2_000).zero?
    end

    # find_each walks by id; the report reads better in playing order.
    found.sort_by! { [ it["date"], it["position"] ] }
    FileUtils.mkdir_p(GaplessScan.report_path.dirname)
    GaplessScan.report_path.write(JSON.pretty_generate(
      "scanned" => checked, "found" => found.size, "tracks" => found
    ))

    puts "\n#{found.size} of #{checked} track(s) carry undeclared padding"
    puts "#{unreadable} track(s) could not be read" if unreadable.positive?
    if decode
      heads = found.count { it["preceded_in_set"] && it["head_silence_s"].to_f.positive? }
      tails = found.count do
        it["followed_in_set"] && it["tail_is_padding"] &&
          it["tail_silence_s"].to_f.positive?
      end
      puts "#{heads} head(s) and #{tails} tail(s) sit on a joint and are trimmable"
      skipped = found.count { GaplessScan.action_for(it, decode) == "no trim needed" }
      puts "#{skipped} track(s) are set edges or real fades, left alone"
    end
    by_year = found.group_by { it["date"][0, 4] }.transform_values(&:size)
    by_year.sort.each { |year, n| puts "  #{year}: #{n}" }
    puts "\nReport: #{GaplessScan.report_path}"

    if ENV["SHEET_ID"].present? && found.any?
      rows = [ GaplessScan::HEADERS ] + GaplessScan.sheet_rows(found, decode)
      GoogleSpreadsheetAppender.call(
        ENV.fetch("SHEET_ID"), ENV.fetch("SHEET_RANGE", "Sheet1!A1"), rows
      )
      puts "Appended #{rows.size - 1} row(s) to spreadsheet #{ENV.fetch('SHEET_ID')}"
    end
  end

  desc "Summarize the last gapless scan report (rake gapless_scan:summary)"
  task summary: :environment do
    path = GaplessScan.report_path
    abort "No report at #{path} - run gapless_scan:run first" unless path.exist?
    data = JSON.parse(path.read)
    rows = data["tracks"]
    decode = rows.any? { it.key?("head_silence_s") }
    puts "scanned #{data['scanned']}, flagged #{data['found']}"
    puts
    actions = rows.group_by { GaplessScan.action_for(it, decode) }
    actions.sort_by { |_k, v| -v.size }.each do |action, list|
      puts format("%-28s %5d", action, list.size)
    end
    next unless decode
    puts
    heads = rows.map { it["head_silence_s"].to_f * 1000 }.reject(&:zero?)
    tails = rows.select { it["tail_is_padding"] }
                .map { it["tail_silence_s"].to_f * 1000 }.reject(&:zero?)
    fades = rows.count { it["tail_silence_s"].to_f.positive? && !it["tail_is_padding"] }
    pct = ->(a, q) { a.empty? ? 0 : a.sort[(a.size * q).clamp(0, a.size - 1)] }
    puts "head silence  n=#{heads.size} min=#{heads.min&.round(1)} " \
         "median=#{pct.call(heads, 0.5)&.round(1)} max=#{heads.max&.round(1)} ms"
    puts "tail cliffs   n=#{tails.size} min=#{tails.min&.round(1)} " \
         "median=#{pct.call(tails, 0.5)&.round(1)} max=#{tails.max&.round(1)} ms"
    puts "tail fades    n=#{fades} (left alone)"
    over = heads.count { it > 60 }
    puts "heads over 60ms: #{over}#{' <- worth eyeballing' if over.positive?}"
  end

  desc "Build the joint review site from the scan report " \
       "(rake gapless_scan:review); SECONDS=n sets how much audio per side"
  task review: :environment do
    report = GaplessScan.report_path
    abort "No report at #{report} - run gapless_scan:run DECODE=1 first" unless report.exist?
    cmd = [ "uv", "run", "scripts/gapless_review.py",
            "--json", report.to_s, "--out", GaplessScan.review_dir.to_s ]
    cmd += [ "--seconds", ENV["SECONDS"] ] if ENV["SECONDS"].present?
    system(*cmd) || abort("Review build failed")
  end

  desc "Serve the joint review site (rake gapless_scan:serve[port])"
  task :serve, [ :port ] => :environment do |_t, args|
    index = GaplessScan.review_dir.join("index.html")
    abort "No review site - run gapless_scan:review first" unless index.exist?
    cmd = [ "uv", "run", "scripts/lead_scan_server.py",
            "--dir", GaplessScan.review_dir.to_s ]
    cmd += [ "--port", args[:port] ] if args[:port]
    system(*cmd)
  end
end
