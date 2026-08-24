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
  HEADER_BYTES = 512 * 1024
  FRAME_PROBE_BYTES = 2_048
  # Below this level the samples are encoder padding rather than performance.
  # Measured ramps run 1-34 and the music above them starts in the thousands, so
  # anything in the low hundreds separates them; 20 lands inside the ramp.
  SILENCE_LEVEL = 50
  # The padding's own noise floor is read from this much of the head. It is flat
  # and only a couple of counts high, so a short window measures it without
  # reaching the performance even on the shortest padding seen.
  HEAD_FLOOR_WINDOW_S = 0.008
  # How far above that floor the level has to climb to be the performance.
  # Anywhere from 4x to 32x picks the same instant to within a tenth of a
  # millisecond, so the exact figure is not what the answer rests on.
  HEAD_FLOOR_MULTIPLE = 8
  # A floor of zero would make any sample at all the edge, so the threshold
  # never drops below this.
  HEAD_FLOOR_MIN = 8
  # A lone spike is not the music starting. Most of this much audio after the
  # candidate has to stay above the floor too.
  HEAD_SUSTAIN_S = 0.005
  HEAD_SUSTAIN_SHARE = 0.6
  # The floor is only meaningful where there is padding to measure. On a track
  # that opens straight into music the window fills with the performance, the
  # threshold is scaled off that, and the edge lands inside the note - cutting
  # its attack off.
  #
  # Verified padding measures 2 to 80; the tracks that went wrong measured 248
  # and up. This is the only signal that separates them. How far the edge lands
  # from the quiet run measured at a fixed level does not: a track whose padding
  # ramps steeply sits 17ms past that run while still being padding, which is
  # the same distance as the tracks that were opening on a note.
  HEAD_FLOOR_MAX = 150
  # Shorter than this is not worth reporting; longer is a real fade, not padding.
  MIN_SILENCE_S = 0.004
  MAX_SILENCE_S = 0.150
  # Cuts are carried as seconds but applied to whole samples, so they are kept
  # to enough places that the sample they land on is not in doubt. Rounded to
  # four places a cut moves by up to a couple of samples at 44.1kHz, which is
  # enough to leave one sample of padding attached to the audio or take one
  # sample of audio away - either way a tick at the joint rather than a gap,
  # too short for any measurement here to see but plainly audible.
  CUT_PRECISION = 7
  # Padding ends in a cliff: the music runs at full level right up to where the
  # silence starts. A track that fades out decays into it instead, and cutting
  # there would take the fade with it. Measured over this much audio before the
  # silent run, a cliff holds a level a fade has already dropped below.
  CLIFF_WINDOW_S = 0.100
  CLIFF_LEVEL = 300
  # Everything is decoded as interleaved stereo, so a sample count covers this
  # many values per frame.
  CHANNELS_PER_FRAME = 2
  # Trailing padding does not sit at a constant level: it decays out of the
  # music, so walking back from the last sample and stopping at the first one
  # above a floor halts partway down the ramp and leaves the louder part behind.
  #
  # Instead the tail is read in short windows and the cut is placed where the
  # level jumps back up into the performance. That boundary is unmistakable -
  # measured jumps run 50x to 300x in a single window.
  TAIL_WINDOW_STEP_S = 0.002
  TAIL_MUSIC_JUMP = 8
  # A window has to be at least this loud to count as the music resuming, so a
  # ripple between two near-silent windows cannot end the walk early.
  TAIL_MUSIC_RMS = 50
  # An mp3 decoder rings for a few frames past the last real sample, at levels
  # a fade would still be audible at. A cutoff edge has to clear that ceiling
  # and tower over what follows it by this much.
  TAIL_RINGING_CEILING = 300
  TAIL_CUTOFF_RATIO = 8
  # Past this the quiet belongs to the recording rather than the encoder.
  TAIL_MAX_CUT_S = 0.150
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
    "Tail zeros (ms)", "Action", "URL"
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
    # Trailing zeros come off wherever they are, set edge or not: removing
    # samples that are exactly zero cannot take any audio with them.
    tail = row["tail_zeros_s"].to_f.positive?
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
        decode ? (row["tail_zeros_s"].to_f * 1000).round(1) : "",
        action_for(row, decode),
        row["url"]
      ]
    end
  end

  # True when the file declares a Xing header but no LAME extension to say how
  # much of it is padding.
  def self.undeclared_padding?(head)
    frame = head.byteslice(id3_length(head), FRAME_PROBE_BYTES).to_s
    (frame.include?("Xing") || frame.include?("Info")) && !frame.include?("LAME")
  end

  def self.id3_length(head)
    return 0 unless head.start_with?("ID3")
    size = head.byteslice(6, 4).to_s.bytes
    return 0 if size.size < 4
    10 + ((size[0] & 0x7f) << 21 | (size[1] & 0x7f) << 14 |
          (size[2] & 0x7f) << 7 | (size[3] & 0x7f))
  end

  # The gapless header sits in the first audio frame, which is however far in
  # the ID3 tag ends. Embedded art pushes that past any fixed guess - measured
  # tags run to 600KB - so a first read establishes the tag length and a second
  # fetches the frame when it fell outside.
  def self.head_bytes(track)
    key = track.mp3_audio.blob.key
    service = track.mp3_audio.blob.service
    head = read_chunk(service, key, HEADER_BYTES)
    return nil if head.nil?
    needed = id3_length(head) + FRAME_PROBE_BYTES
    return head if needed <= head.bytesize
    read_chunk(service, key, needed) || head
  end

  def self.read_chunk(service, key, bytes)
    service.download_chunk(key, 0...bytes).to_s.force_encoding(Encoding::BINARY)
  rescue StandardError
    nil
  end

  # Seconds of near-silence at each edge, whether the tail is a cliff, where the
  # head padding provably ends, and how much of the tail is pure digital zero.
  def self.edges(path)
    tail, cliff = tail_silence(path)
    [ head_silence(path), tail, cliff, head_plateau_s(path), tail_zeros_s(path) ]
  end

  # How much encoder padding trails the audio.
  #
  # Read in short windows walking back from the end: the padding decays out of
  # the performance rather than sitting at a fixed level, so the boundary is
  # where the level jumps back up into music, not where it crosses a threshold.
  # Where no such jump exists the track fades out deliberately, and the walk
  # falls back to the trailing run below the music floor - still padding, just
  # reached the long way.
  def self.tail_zeros_s(path)
    rate = sample_rate(path)
    pcm = decode(path, [], pre: [ "-sseof", "-1.00" ])
    return 0.0 if pcm.empty?
    frames = pcm.each_slice(CHANNELS_PER_FRAME).map { it.map(&:abs).max }
    seconds = cutoff_edge_s(frames, rate) ||
              music_resumes_at(frames, rate) ||
              fade_padding_s(frames, rate)
    return 0.0 if seconds.nil? || seconds > TAIL_MAX_CUT_S
    seconds < MIN_SILENCE_S ? 0.0 : seconds.round(CUT_PRECISION)
  end

  # Seconds from the end at which the level jumps back into the performance.
  def self.music_resumes_at(frames, rate)
    step = (TAIL_WINDOW_STEP_S * rate).round
    limit = (TAIL_MAX_CUT_S * rate).round
    previous = nil
    (0...limit).step(step) do |offset|
      window = frames[[ frames.size - offset - step, 0 ].max...(frames.size - offset)]
      break if window.nil? || window.empty?
      level = rms(window)
      if previous && level > TAIL_MUSIC_RMS && level > previous * TAIL_MUSIC_JUMP
        return offset / rate.to_f
      end
      previous = level
    end
    nil
  end

  # Where a track was cut off rather than faded, the last frame of music towers
  # over everything after it: the level collapses by more than an order of
  # magnitude in a single frame, and what follows is the decoder's own ringing
  # rather than audio. Landing on that frame matters, because the ringing sits
  # well above the level a fade decays through - reading it as music leaves a
  # few samples of near-silence at the cut, which is a click at a joint.
  #
  # A fade has no such frame, so this finds nothing and the gentler walks below
  # take over.
  def self.cutoff_edge_s(frames, rate)
    limit = [ (TAIL_MAX_CUT_S * rate).round, frames.size - 1 ].min
    after = 0
    (frames.size - 1).downto(frames.size - limit) do |index|
      level = frames[index]
      return (frames.size - 1 - index) / rate.to_f if
        level > TAIL_RINGING_CEILING && level > after * TAIL_CUTOFF_RATIO
      after = [ after, level ].max
    end
    nil
  end

  # A deliberate fade has no jump to find, so the padding is whatever trails
  # below the level at which the music is still audible.
  def self.fade_padding_s(frames, rate)
    index = frames.rindex { it > TAIL_MUSIC_RMS }
    return nil if index.nil?
    (frames.size - index - 1) / rate.to_f
  end

  def self.rms(values)
    return 0.0 if values.empty?
    Math.sqrt(values.sum { it.to_f * it } / values.size)
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

  def self.at_joint?(track)
    preceded_in_set?(track) || followed_in_set?(track)
  end

  def self.head_silence(path)
    pcm = decode(path, [ "-t", format("%.4f", MAX_SILENCE_S + 0.4) ])
    quiet = pcm.take_while { it.abs < SILENCE_LEVEL }.size / CHANNELS_PER_FRAME
    bounded(quiet / sample_rate(path).to_f)
  end

  # Where the head padding ends, or nil when no boundary can be established.
  #
  # Fixed thresholds cannot find it, at any number of levels. The level the
  # performance starts at varies from track to track by more than the levels
  # themselves: a track whose music comes in at 130 never reaches a rung above
  # that, so only the lowest one sees the edge and nothing agrees with it. One
  # joint in eight was left uncut for that reason.
  #
  # What is constant is the padding: a flat floor of a couple of counts of
  # dither, whatever the music does afterwards. Measuring that floor and taking
  # the edge where the level leaves it behind works at either extreme, because
  # the threshold is derived from the track rather than assumed.
  def self.head_plateau_s(path)
    pcm = decode(path, [ "-t", format("%.4f", MAX_SILENCE_S + 0.4) ])
    return nil if pcm.empty?
    rate = sample_rate(path)
    frames = pcm.each_slice(CHANNELS_PER_FRAME).map { it.map(&:abs).max }
    floor = head_floor(frames, rate)
    return nil if floor > HEAD_FLOOR_MAX
    threshold = [ floor * HEAD_FLOOR_MULTIPLE, HEAD_FLOOR_MIN ].max
    edge = head_edge_index(frames, rate, floor, threshold)
    return nil if edge.nil?
    (edge / rate.to_f).round(CUT_PRECISION)
  end

  def self.head_floor(frames, rate)
    window = frames.first((HEAD_FLOOR_WINDOW_S * rate).round)
    window.empty? ? 0 : window.max
  end

  def self.head_edge_index(frames, rate, floor, threshold)
    sustain = (HEAD_SUSTAIN_S * rate).round
    limit = [ (MAX_SILENCE_S * rate).round, frames.size - sustain ].min
    (0...limit).each do |index|
      next if frames[index] < threshold
      held = frames[index, sustain].count { it > floor * 2 }
      return index if held > sustain * HEAD_SUSTAIN_SHARE
    end
    nil
  end

  # Trailing silence, and whether the audio before it ends in a cliff (encoder
  # padding, safe to cut) or a decay (a real fade, which must be kept).
  def self.tail_silence(path)
    pcm = decode(path, [], pre: [ "-sseof", "-0.50" ])
    return [ 0.0, false ] if pcm.empty?
    rate = sample_rate(path)
    quiet = pcm.reverse.take_while { it.abs < SILENCE_LEVEL }.size / CHANNELS_PER_FRAME
    seconds = bounded(quiet / rate.to_f)
    return [ 0.0, false ] if seconds.zero?
    window = (CLIFF_WINDOW_S * rate).ceil * CHANNELS_PER_FRAME
    before = pcm.first([ pcm.size - quiet * CHANNELS_PER_FRAME, 0 ].max).last(window)
    [ seconds, before.any? && before.max { |a, b| a.abs <=> b.abs }.abs >= CLIFF_LEVEL ]
  end

  # Splits the rows into the runs that have to be rendered together and the
  # tracks that can be trimmed on their own.
  #
  # A joint is two adjacent in-set tracks, and consecutive joints chain: a track
  # in the middle of a segued sequence is crossfaded at both ends, so its file
  # depends on both neighbours and the whole run is one unit of work. Everything
  # else only needs its own edges cut.
  def self.partition_runs(rows)
    by_show = rows.group_by { [ it["date"], it["set"] ] }
    runs = []
    joined = Set.new
    by_show.each_value do |group|
      positions = group.index_by { it["position"] }
      group.sort_by { it["position"] }.each do |row|
        nxt = positions[row["position"] + 1]
        next unless nxt && row["followed_in_set"] && nxt["preceded_in_set"]
        if runs.last&.last&.equal?(row)
          runs.last << nxt
        else
          runs << [ row, nxt ]
        end
        joined << row << nxt
      end
    end
    [ runs, rows.reject { joined.include?(it) } ]
  end

  def self.bounded(seconds)
    return 0.0 if seconds < MIN_SILENCE_S || seconds > MAX_SILENCE_S
    seconds.round(CUT_PRECISION)
  end

  # Decoded at the file's own sample rate.
  #
  # Resampling would defeat the measurement: it interpolates, so samples that
  # were exactly zero come out non-zero and near-zero ones come out as zero.
  # The cuts are applied by atrim on the original stream, so they have to be
  # measured on that stream too.
  # Cached per file: every edge measurement asks for it, and each track is
  # probed and discarded before the next one starts.
  def self.sample_rate(path)
    @sample_rates ||= {}
    @sample_rates[path.to_s] ||= begin
      out, _err, status = Open3.capture3(
        "ffprobe", "-v", "error", "-select_streams", "a:0",
        "-show_entries", "stream=sample_rate", "-of", "default=nw=1:nk=1", path.to_s
      )
      rate = out.to_s.strip.to_i
      status.success? && rate.positive? ? rate : 44_100
    end
  end

  def self.decode(path, post, pre: [])
    out, _err, status = Open3.capture3(
      "ffmpeg", "-v", "error", *pre, "-i", path.to_s, *post,
      "-f", "s16le", "-acodec", "pcm_s16le", "-ar", sample_rate(path).to_s, "-"
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
      # A track whose header is already correct still belongs in the report when
      # it sits at a joint. It has no padding of its own to cut, but its
      # neighbour's tick is smoothed by a crossfade that both files must share,
      # and a run can only include a track the report knows about. Carini into
      # Sand on 2025-09-17 is the case: Sand was clean, so the joint went
      # untreated and kept a 3041-count step.
      padding = GaplessScan.undeclared_padding?(head)
      next unless padding || GaplessScan.at_joint?(track)

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
          head_s, tail_s, cliff, plateau, zeros = GaplessScan.edges(file.path)
          # Trailing pure zeros: removable without touching any audio.
          row["tail_zeros_s"] = zeros
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

  desc "Apply the trims the scan found (rake gapless_scan:apply); " \
       "DRY_RUN=1 renders only, DATE=YYYY-MM-DD, FROM/TO=YYYY-MM-DD or LIMIT=n " \
       "scopes it, HEADS=0 or TAILS=0 skips one edge, " \
       "MAX_HEAD_MS=n holds back head cuts above n milliseconds"
  task apply: :environment do
    report = GaplessScan.report_path
    abort "No report at #{report} - run gapless_scan:run DECODE=1 first" unless report.exist?
    rows = JSON.parse(report.read)["tracks"]
    rows = rows.select { it["date"] == ENV["DATE"] } if ENV["DATE"].present?
    if ENV["FROM"].present? || ENV["TO"].present?
      from = ENV["FROM"].presence || "1900-01-01"
      to = ENV["TO"].presence || "2999-12-31"
      rows = rows.select { it["date"] >= from && it["date"] <= to }
    end
    heads = ENV["HEADS"] != "0"
    tails = ENV["TAILS"] != "0"
    dry_run = ENV["DRY_RUN"] == "1"
    max_head = ENV["MAX_HEAD_MS"].presence&.to_f&.fdiv(1000)

    # Only what the scan proved safe: a head where every threshold agreed where
    # the padding ends, a tail that is pure digital zero.
    # A head cut is inferred from where padding appears to end, so an unusually
    # large one is more likely a mismeasurement that would eat the first note.
    # Such a track is held back whole rather than trimmed at the tail alone: it
    # may sit in a run, and rewriting its neighbours without it would leave the
    # joint half-treated.
    # A no-cut track is only worth rewriting if the track it joins is being
    # rewritten anyway - otherwise every clean track inside a set would be
    # re-encoded to no purpose.
    cutting = rows.each_with_object(Set.new) do |row, set|
      h = heads && row["preceded_in_set"] ? row["head_cut_s"].to_f : 0.0
      t = tails ? row["tail_zeros_s"].to_f : 0.0
      set << [ row["date"], row["set"], row["position"] ] if h.positive? || t.positive?
    end
    joint_candidate = lambda do |row|
      key = [ row["date"], row["set"] ]
      (row["preceded_in_set"] && cutting.include?(key + [ row["position"] - 1 ])) ||
        (row["followed_in_set"] && cutting.include?(key + [ row["position"] + 1 ]))
    end

    held = []
    work = rows.filter_map do |row|
      head = heads && row["preceded_in_set"] ? row["head_cut_s"].to_f : 0.0
      tail = tails ? row["tail_zeros_s"].to_f : 0.0
      if max_head && head > max_head
        held << row
        next
      end
      # A track with nothing to cut is still kept when it sits at a joint: it
      # earns its place in a run by taking half of the neighbouring crossfade,
      # not by having padding of its own. Dropping it here would leave the
      # joint untreated, which is how Sand kept its step.
      next if head.zero? && tail.zero? && !joint_candidate.call(row)
      [ row, head, tail ]
    end
    if held.any?
      puts "Holding back #{held.size} track(s) with a head cut over #{ENV['MAX_HEAD_MS']}ms:"
      held.sort_by { -it["head_cut_s"].to_f }.each do |row|
        puts "  #{(row['head_cut_s'].to_f * 1000).round(1)}ms  " \
             "#{row['date']} t#{row['position']} #{row['title']}"
      end
      puts
    end
    work = work.first(ENV["LIMIT"].to_i) if ENV["LIMIT"].present?
    abort "Nothing to trim" if work.empty?

    # Tracks that meet at a joint are rewritten together, because the crossfade
    # that removes the tick between them belongs half to each file. The rest
    # only need their own edges cut.
    cuts_by_id = work.to_h { |row, head, tail| [ row["track_id"], { head:, tail: } ] }
    runs, solo_rows = GaplessScan.partition_runs(work.map(&:first))
    solo = solo_rows.map { |row| [ row, *cuts_by_id[row["track_id"]].values_at(:head, :tail) ] }
    total = runs.size + solo.size

    puts dry_run ? "DRY RUN: rendering #{runs.size} run(s) and #{solo.size} trim(s)\n\n"
                 : "Rewriting #{runs.size} run(s) and #{solo.size} track(s)\n\n"
    applied = 0
    failures = []
    step = 0

    runs.each do |run|
      step += 1
      tracks = run.map { Track.find_by(id: it["track_id"]) }
      if tracks.any?(&:nil?)
        next failures << [ "#{run.first['date']} run", "track not found" ]
      end
      begin
        cuts = tracks.to_h { [ it.id, cuts_by_id.fetch(it.id, { head: 0.0, tail: 0.0 }) ] }
        result = GaplessJointService.call(tracks, cuts:, dry_run:)
        applied += 1
        puts "#{result[:applied] ? 'JOINED' : 'RENDERED'} [#{step}/#{total}]  " \
             "#{run.first['date']} t#{run.first['position']}..t#{run.last['position']}"
        result[:outputs].each { puts "  #{it[:title]} -> #{it[:seconds].round(3)}s" }
        $stdout.flush
      rescue GaplessJointService::Error => e
        failures << [ "#{run.first['date']} joint", e.message ]
      end
    end

    solo.each do |row, head, tail|
      step += 1
      track = Track.find_by(id: row["track_id"])
      next failures << [ row["label"] || row["url"], "track not found" ] unless track
      begin
        result = GaplessTrimService.call(track, head_cut: head, tail_cut: tail, dry_run:)
        applied += 1
        puts "#{result[:applied] ? 'TRIMMED' : 'RENDERED'} [#{step}/#{total}]  " \
             "#{row['date']} t#{row['position']}  #{result[:title]}"
        cuts = []
        cuts << "head #{(head * 1000).round(1)}ms" if head.positive?
        cuts << "tail #{(tail * 1000).round(1)}ms" if tail.positive?
        puts "  cut:     #{cuts.join(', ')} " \
             "(#{result[:original_duration_s]}s -> #{result[:trimmed_duration_s]}s)"
        puts "  backup:  #{result[:backup_path]}" if result[:backup_path]
        $stdout.flush
      rescue GaplessTrimService::Error => e
        failures << [ "#{row['date']} #{row['title']}", e.message ]
      end
    end

    puts "\n#{applied} of #{total} #{dry_run ? 'rendered' : 'rewritten'}"
    if failures.any?
      puts "Failures:"
      failures.each { |what, msg| puts "  #{what}: #{msg}" }
    end
    if !dry_run && applied.positive?
      puts "Clearing Rails cache..."
      Rails.cache.clear
    end
    exit 1 if failures.any?
  end

  desc "Scan only the named shows (rake gapless_scan:shows DATES=a,b,c); " \
       "always measures edges, OUT=<dir> sets where the report lands"
  task shows: :environment do
    dates = ENV.fetch("DATES").split(",").map(&:strip)
    rows = []
    dates.each do |date|
      show = Show.find_by(date:)
      next puts("no show on #{date}") unless show
      show.tracks.includes(mp3_audio_attachment: :blob).order(:position).each do |track|
        next if track.missing_audio?
        head = GaplessScan.head_bytes(track)
        next unless head && GaplessScan.undeclared_padding?(head)
        file = Tempfile.new([ "gapless_#{track.id}", ".mp3" ], binmode: true)
        begin
          track.mp3_audio.blob.download { |chunk| file.write(chunk) }
          file.flush
          head_s, tail_s, cliff, plateau, zeros = GaplessScan.edges(file.path)
          rows << {
            "mp3_url" => track.mp3_url,
            "duration_s" => (track.duration.to_i / 1000.0).round(3),
            "track_id" => track.id, "date" => date, "position" => track.position,
            "title" => track.title, "url" => track.url, "set" => track.set,
            "preceded_in_set" => GaplessScan.preceded_in_set?(track),
            "followed_in_set" => GaplessScan.followed_in_set?(track),
            "head_silence_s" => head_s, "tail_silence_s" => tail_s,
            "tail_is_padding" => cliff, "head_cut_s" => plateau,
            "tail_zeros_s" => zeros
          }
          puts "  #{date} t#{track.position} #{track.title}: " \
               "head=#{plateau ? (plateau * 1000).round(1) : '-'} " \
               "tail=#{(zeros * 1000).round(1)}"
          $stdout.flush
        ensure
          file.close!
        end
      end
    end
    path = GaplessScan.report_path
    FileUtils.mkdir_p(path.dirname)
    path.write(JSON.pretty_generate(
      "scanned" => dates.size, "found" => rows.size, "tracks" => rows
    ))
    puts "\n#{rows.size} track(s) -> #{path}"
  end

  desc "Put back the audio a trim replaced (rake gapless_scan:restore DATE=YYYY-MM-DD); " \
       "SLUGS=a,b limits it to named tracks, DRY_RUN=1 reports only"
  task restore: :environment do
    dir = GaplessTrimService::BACKUP_DIR
    abort "No backups at #{dir}" unless dir.directory?
    date = ENV["DATE"].presence || abort("DATE=YYYY-MM-DD is required")
    dry_run = ENV["DRY_RUN"] == "1"
    only = ENV["SLUGS"].presence&.split(",")&.map(&:strip)

    show = Show.find_by(date:) || abort("No show on #{date}")
    # The filename carries the blob key the track had when it was backed up,
    # which is no longer its key - date and slug are what still identify it.
    backups = Dir.glob(dir.join("#{date}_*.mp3")).to_h do |path|
      [ File.basename(path).delete_prefix("#{date}_").sub(/_[0-9a-z]+\.mp3\z/, ""), path ]
    end
    abort "No backups for #{date}" if backups.empty?
    backups = backups.slice(*only) if only

    work = backups.filter_map do |slug, path|
      track = show.tracks.find_by(slug:)
      next puts("  no track for #{slug.inspect}, skipping") if track.nil?
      [ track, path ]
    end
    abort "Nothing to restore" if work.empty?

    puts "#{dry_run ? 'DRY RUN: would restore' : 'Restoring'} " \
         "#{work.size} track(s) on #{date}\n\n"
    work.each_with_index do |(track, path), i|
      size = File.size(path)
      puts "  [#{i + 1}/#{work.size}] t#{track.position} #{track.title} " \
           "(#{(size / 1024.0**2).round(1)}MB)"
      next if dry_run
      track.mp3_audio.attach(
        io: File.open(path), filename: track.friendly_filename,
        content_type: "audio/mpeg"
      )
      track.reload
      track.process_mp3_audio
      PlaylistTrack.where(track_id: track.id).find_each(&:save!)
    end

    next if dry_run
    # Once for the show rather than once per track: the per-track call sums an
    # association that may still hold the durations from before the restore.
    show.reload.save_duration
    Rails.cache.clear
    puts "\n#{work.size} track(s) restored"
  end
end
