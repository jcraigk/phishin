require "base64"
require "shellwords"

# Finds tracks whose title holds two songs joined by a segue ("Mike's Song >
# I Am Hydrogen") and splits them into two tracks after a human picks the cut
# point. Same scan/review/apply shape as lead_scan.rake, with its own output
# root and ignore list; the preview server is shared unchanged.
module SplitScan
  SCAN_SCRIPT = "scripts/audio_split_analysis.py".freeze
  SCAN_ROOT = "data/split_scan".freeze

  FLAGS = [ "--ignore-file", "#{SCAN_ROOT}/ignore.txt" ].freeze

  def self.run(selector, out_dir, log_path: nil)
    unless system("which uv > /dev/null 2>&1")
      abort "uv not found. Install it first: https://docs.astral.sh/uv/"
    end

    cmd = [
      "uv", "run", SCAN_SCRIPT,
      *selector,
      *FLAGS,
      "--json", "#{out_dir}/report.json",
      "--html", "#{out_dir}/review.html"
    ]
    cmd.concat(Shellwords.split(ENV["EXTRA"])) if ENV["EXTRA"].present?

    shell = Shellwords.join(cmd)
    shell = "set -o pipefail; #{shell} 2>&1 | tee #{Shellwords.escape(log_path)}" if log_path

    puts "Running: #{shell}"
    ok = system(shell)
    puts ok ? "Done. Review: #{out_dir}/review.html" : "FAILED (see output above)"
    ok
  end

  # Years already reviewed, one per line (ranges like "1983-1990" allowed, #
  # comments ignored). They stay on disk and stay servable by direct url; the
  # index just stops listing them so what is left is what still needs work.
  def self.done_years
    path = "#{SCAN_ROOT}/done.txt"
    return Set.new unless File.exist?(path)
    File.readlines(path, chomp: true).each_with_object(Set.new) do |line, set|
      line = line.sub(/#.*/, "").strip
      next if line.empty?
      if (m = line.match(/\A(\d{4})\s*-\s*(\d{4})\z/))
        (m[1].to_i..m[2].to_i).each { set << it.to_s }
      else
        set << line
      end
    end
  end

  FONT_DIR = "node_modules/@fontsource/open-sans-condensed/files".freeze

  # Ruby-side twin of embedded_fonts() in audio_split_analysis.py: the index has
  # to look like the review pages, and those inline the font so they work over
  # file:// with no network. Yields nothing if node_modules is absent, in which
  # case the stack falls back to system sans.
  def self.embedded_fonts
    [ 300, 700 ].filter_map do |weight|
      path = "#{FONT_DIR}/open-sans-condensed-latin-#{weight}-normal.woff2"
      next unless File.exist?(path)
      b64 = Base64.strict_encode64(File.binread(path))
      %(@font-face { font-family: "Open Sans Condensed"; font-style: normal; ) +
        %(font-weight: #{weight}; font-display: swap; ) +
        %(src: url(data:font/woff2;base64,#{b64}) format("woff2"); })
    end.join("\n    ")
  end

  def self.write_index
    done = done_years
    year_dirs = Dir.glob("#{SCAN_ROOT}/[0-9][0-9][0-9][0-9]").sort
                   .reject { done.include?(File.basename(it)) }
    return puts("No year folders under #{SCAN_ROOT}; nothing to index") if year_dirs.empty?

    totals = Hash.new(0)
    rows = year_dirs.map do |dir|
      year = File.basename(dir)
      summary_path = File.join(dir, "summary.json")
      unless File.exist?(summary_path)
        next %(<tr><td>#{year}</td><td class="pending">no report yet (scan running or failed)</td><td></td></tr>)
      end

      summary = JSON.parse(File.read(summary_path))
      candidates = summary.fetch("candidates", 0)
      multi = summary.fetch("multi_segue", 0)
      totals["candidates"] += candidates
      totals["multi_segue"] += multi
      %(<tr><td><a href="#{year}/review.html">#{year}</a></td>) +
        %(<td>#{candidates}</td><td>#{multi}</td></tr>)
    end

    File.write("#{SCAN_ROOT}/index.html", <<~HTML)
      <!doctype html>
      <meta charset="utf-8">
      <title>Track split reports</title>
      <link rel="icon" href='data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">✂️</text></svg>'>

      <style>
        #{embedded_fonts}
        /* Same tokens as the review pages, so moving between them feels like
           one app rather than two tools. */
        :root {
          --bg: #ffffff; --fg: #1c1c1e; --muted: #6b6b70;
          --line: #e3e3e7; --card: #fafafa; --link: #2f6fd0;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --bg: #14171d; --fg: #e6e9ef; --muted: #8b95a7;
            --line: #262b35; --card: #1a1e26; --link: #7fb3f0;
          }
        }
        * { box-sizing: border-box; }
        body { font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
               margin: 2rem auto; max-width: 700px; padding: 0 1.5rem;
               background: var(--bg); color: var(--fg);
               -webkit-font-smoothing: antialiased; }
        h1 { font-family: "Open Sans Condensed", -apple-system, sans-serif;
             font-size: 30px; font-weight: 700; letter-spacing: .01em; margin: 0 0 1.2rem; }
        a { color: var(--link);
            text-decoration-color: color-mix(in srgb, var(--link) 45%, transparent);
            text-underline-offset: 2px; }
        a:hover { text-decoration-color: currentColor; }
        table { border-collapse: collapse; width: 100%; }
        th, td { text-align: left; padding: .5rem .8rem; border-bottom: 1px solid var(--line); }
        th { font-family: "Open Sans Condensed", -apple-system, sans-serif;
             font-size: 15px; font-weight: 700; color: var(--muted);
             text-transform: uppercase; letter-spacing: .04em; }
        td + td, th + th { text-align: right; font-variant-numeric: tabular-nums; }
        tbody tr:hover { background: var(--card); }
        tfoot td { font-weight: 700; border-bottom: none; }
        .pending { color: var(--muted); text-align: left; font-style: italic; }
        .meta { color: var(--muted); margin: -.6rem 0 1.4rem; }
      </style>
      <h1>Track split reports</h1>
      <p class="meta">Generated #{Time.now.strftime('%Y-%m-%d %H:%M')}</p>
      <table>
        <thead>
          <tr><th>Year</th><th>Candidates</th><th>Multi-segue</th></tr>
        </thead>
        <tbody>#{rows.join("\n")}</tbody>
        <tfoot>
          <tr><td>Total</td><td>#{totals['candidates']}</td><td>#{totals['multi_segue']}</td></tr>
        </tfoot>
      </table>
    HTML
    puts "Index written to #{SCAN_ROOT}/index.html"
  end

  # Approved entries name a track by the blob its audio was scanned from, the
  # same handle lead_scan:apply uses: a slug can change, a blob key cannot.
  def self.resolve_track(entry)
    key = File.basename(URI.parse(entry["mp3_url"]).path, ".mp3")
    blob = ActiveStorage::Blob.find_by(key:)
    attachment = blob && ActiveStorage::Attachment.find_by(
      blob_id: blob.id, record_type: "Track", name: "mp3_audio"
    )
    return [ nil, "blob #{key} not found (audio replaced since scan?)" ] unless attachment
    [ attachment.record, nil ]
  end

  # Gap columns of the songs involved point at their neighbouring performances,
  # and a split changes both which songs a show contains and the slug of the
  # track that held them. Recompute the show, then every show holding the next
  # performance of an affected song, so their `previous_performance_*` columns
  # stop naming a slug that no longer exists.
  # Only the split songs can have moved, so every recompute is scoped to them:
  # unscoped, each call would rework the whole set list, and update_previous
  # would rewrite the entire performance history of every song in the show.
  def self.refresh_gaps(show, songs)
    song_ids = songs.map(&:id).uniq
    next_shows = song_ids.filter_map do |song_id|
      Track.joins(:show, :songs)
           .where(songs: { id: song_id })
           .where("tracks.set <> ?", "S")
           .where.not(tracks: { exclude_from_stats: true })
           .where("shows.performance_gap_value > 0")
           .where("shows.date > ?", show.date)
           .order("shows.date ASC, tracks.position ASC")
           .first&.show
    end.uniq

    GapService.call(show, update_previous: true, song_ids:)
    next_shows.each { GapService.call(it, song_ids:) }
    next_shows
  end
end

namespace :split_scan do
  desc "Scan one show for segue tracks (rake split_scan:show[1989-05-26])"
  task :show, [ :date ] => :environment do |_t, args|
    abort "Usage: rake split_scan:show[YYYY-MM-DD]" unless args[:date]
    out_dir = "#{SplitScan::SCAN_ROOT}/shows/#{args[:date]}"
    exit 1 unless SplitScan.run([ "--show", args[:date] ], out_dir)
  end

  desc "Scan one year of shows (rake split_scan:year[1989])"
  task :year, [ :year ] => :environment do |_t, args|
    abort "Usage: rake split_scan:year[YYYY]" unless args[:year]
    out_dir = "#{SplitScan::SCAN_ROOT}/#{args[:year]}"
    ok = SplitScan.run(
      [ "--year", args[:year] ],
      out_dir,
      log_path: "#{SplitScan::SCAN_ROOT}/#{args[:year]}.log"
    )
    SplitScan.write_index
    exit 1 unless ok
  end

  desc "Regenerate the index page linking all year reports (data/split_scan/index.html)"
  task :index do
    SplitScan.write_index
  end

  desc "Regenerate review pages from existing reports (rake split_scan:rebuild or " \
       "split_scan:rebuild[1989]); no API calls"
  task :rebuild, [ :year ] do |_t, args|
    dirs =
      if args[:year]
        [ "#{SplitScan::SCAN_ROOT}/#{args[:year]}" ].select { File.exist?("#{it}/report.json") }
      else
        Dir.glob("#{SplitScan::SCAN_ROOT}/{[0-9][0-9][0-9][0-9],shows/*}")
           .select { File.exist?("#{it}/report.json") }
      end
    abort "No reports found under #{SplitScan::SCAN_ROOT}" if dirs.empty?
    cmd = [ "uv", "run", SplitScan::SCAN_SCRIPT, *SplitScan::FLAGS ] +
          dirs.flat_map { [ "--rebuild", it ] }
    system(*cmd) || abort("Rebuild failed")
    SplitScan.write_index
  end

  desc "Serve review pages with live split previews (rake split_scan:serve for all " \
       "years, or split_scan:serve[1989] for one)"
  task :serve, [ :year, :port ] => :environment do |_t, args|
    dir = args[:year] ? "#{SplitScan::SCAN_ROOT}/#{args[:year]}" : SplitScan::SCAN_ROOT
    if args[:year] && !File.exist?("#{dir}/review.html")
      abort "No review page at #{dir}/review.html"
    end
    # The lead scan's server renders arbitrary {mp3_url, trim_start, trim_end}
    # segments, which is exactly what the two audition clips need. Shared as is.
    cmd = [ "uv", "run", "scripts/lead_scan_server.py", "--dir", dir ]
    cmd += [ "--port", args[:port] ] if args[:port]
    system(*cmd)
  end

  desc "Apply approved track splits (rake split_scan:apply[path/to/approved.json]); " \
       "DRY_RUN=1 renders only, ONLY=<track url> filters"
  task :apply, [ :json_path ] => :environment do |_t, args|
    abort "Usage: rake split_scan:apply[path/to/approved.json]" unless args[:json_path]
    entries = JSON.parse(File.read(args[:json_path]))

    if ENV["ONLY"].present?
      track = Track.by_url(ENV["ONLY"])
      abort "No track found for #{ENV['ONLY']} (expected a track url like " \
            "https://phish.in/1989-05-26/mikes-song-i-am-hydrogen)" unless track
      position_token = format(" t%02d ", track.position)
      entries = entries.select do |e|
        e["label"].start_with?("#{track.show.date} ") && e["label"].include?(position_token)
      end
    end

    abort "No matching entries" if entries.empty?

    dry_run = ENV["DRY_RUN"] == "1"
    puts dry_run ? "DRY RUN: rendering both halves without changing anything\n\n"
                 : "Applying #{entries.size} split(s)\n\n"
    applied = 0
    failures = []
    # Gaps are recomputed per show once all of its splits are in, not per split:
    # a show with two splits would otherwise pay for the same recomputation
    # twice and see the first pass work from a half-changed set list.
    touched = Hash.new { |h, k| h[k] = [] }

    entries.each_with_index do |entry, idx|
      label = entry["label"]
      progress = "[#{idx + 1}/#{entries.size}]"
      if entry["cut_s"].blank?
        failures << [ label, "no cut_s in the export" ]
        next
      end

      track, error = SplitScan.resolve_track(entry)
      if error
        failures << [ label, error ]
        next
      end

      begin
        result = TrackSplitService.call(track, cut_s: entry["cut_s"].to_f, dry_run:)
        applied += 1
        status = result[:applied] ? "APPLIED" : "RENDERED"
        display = label.sub(/\A(\d{4}-\d{2}-\d{2} .*?) t\d+ /, '\1 ')
        puts "#{status} #{progress}  #{display}"
        puts "  part 1:  #{result[:part1_title]} (#{result[:part1_duration_s]}s) " \
             "-> #{result[:part1_path]}"
        puts "  part 2:  #{result[:part2_title]} (#{result[:part2_duration_s]}s) " \
             "-> #{result[:part2_path]}"
        puts "  backup:  #{result[:backup_path]}" if result[:backup_path]
        if result[:applied]
          puts "  tracks:  #{result[:part1_url]}"
          puts "           #{result[:part2_url]}"
          puts "  moved:   #{result[:likes_copied]} like(s), " \
               "#{result[:tags_copied]} tag(s), " \
               "#{result[:playlist_entries]} playlist entr(ies)"
          result[:notes].each { puts "  note:    #{it}" }
          touched[track.show] |= result[:song_ids].map { Song.find(it) }
        end
      rescue TrackSplitService::Error => e
        failures << [ label, e.message ]
      end
    end

    touched.each do |show, songs|
      puts "\nRecomputing gaps for #{show.date}..."
      next_shows = SplitScan.refresh_gaps(show, songs)
      puts "  also refreshed #{next_shows.size} later show(s)" if next_shows.any?
    end

    puts "\n#{applied} of #{entries.size} entries #{dry_run ? 'rendered' : 'applied'}"
    if failures.any?
      puts "Failures:"
      failures.each { |label, msg| puts "  #{label}: #{msg}" }
    end

    if !dry_run && applied.positive?
      puts "Clearing Rails cache..."
      Rails.cache.clear
    end

    exit 1 if failures.any?
  end
end
