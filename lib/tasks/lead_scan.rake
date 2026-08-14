require "base64"
require "shellwords"

# Leading-edge counterpart to audio_edges.rake: scans set/encore openers for
# crowd noise before the music begins. Same scan/review/apply process, but a
# separate use case with its own output root, ignore list, and tuning: flag
# runs over 5s, keep 0.5s of crowd, 0.2s fade-in.
module LeadScan
  SCAN_SCRIPT = "scripts/audio_edge_analysis.py".freeze
  SCAN_ROOT = "data/lead_scan".freeze
  MIN_DURATION = 5.0
  KEEP_LEAD = 0.5
  FADE_IN = 0.2
  MIN_CUT = 4.5

  TUNING_FLAGS = [
    "--edges", "leading",
    "--min-duration", MIN_DURATION.to_s,
    "--keep-lead", KEEP_LEAD.to_s,
    "--fade-in", FADE_IN.to_s,
    "--min-cut", MIN_CUT.to_s,
    "--ignore-file", "#{SCAN_ROOT}/ignore.txt"
  ].freeze

  def self.run(selector, out_dir, log_path: nil)
    unless system("which uv > /dev/null 2>&1")
      abort "uv not found. Install it first: https://docs.astral.sh/uv/"
    end

    cmd = [
      "uv", "run", SCAN_SCRIPT,
      *selector,
      *TUNING_FLAGS,
      "--trim-dir", "#{out_dir}/trimmed",
      "--plot-dir", "#{out_dir}/plots",
      "--json", "#{out_dir}/report.json",
      "--html", "#{out_dir}/review.html"
    ]
    cmd << "--stream" unless ENV["STREAM"] == "0"
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

  # Ruby-side twin of embedded_fonts() in audio_edge_analysis.py: the index has
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
        next %(<tr><td>#{year}</td><td class="pending">no report yet (scan running or failed)</td></tr>)
      end

      summary = JSON.parse(File.read(summary_path))
      # A cappella and not-trimmed counts are always zero now that both are
      # folded into the reviewable list, so only the trim count is shown.
      trims = summary.fetch("trims", 0)
      totals["trims"] += trims
      %(<tr><td><a href="#{year}/review.html">#{year}</a></td><td>#{trims}</td></tr>)
    end

    File.write("#{SCAN_ROOT}/index.html", <<~HTML)
      <!doctype html>
      <meta charset="utf-8">
      <title>Track lead-in trim reports</title>
      <link rel="icon" href='data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text y=".9em" font-size="90">🎬</text></svg>'>

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
        /* Counts read as data, so they get the same tabular figures the review
           page uses for times. */
        td + td, th + th { text-align: right; font-variant-numeric: tabular-nums; }
        tbody tr:hover { background: var(--card); }
        tfoot td { font-weight: 700; border-bottom: none; }
        /* Prose, not a count - it keeps the left alignment the numbers give up. */
        .pending { color: var(--muted); text-align: left; font-style: italic; }
        .meta { color: var(--muted); margin: -.6rem 0 1.4rem; }
      </style>
      <h1>Track lead-in trim reports</h1>
      <p class="meta">Generated #{Time.now.strftime('%Y-%m-%d %H:%M')}</p>
      <table>
        <thead>
          <tr><th>Year</th><th>Trims</th></tr>
        </thead>
        <tbody>#{rows.join("\n")}</tbody>
        <tfoot>
          <tr><td>Total</td><td>#{totals['trims']}</td></tr>
        </tfoot>
      </table>
    HTML
    puts "Index written to #{SCAN_ROOT}/index.html"
  end
end

namespace :lead_scan do
  desc "Scan one show's set openers for lead-in noise (rake lead_scan:show[1996-11-02])"
  task :show, [ :date ] => :environment do |_t, args|
    abort "Usage: rake lead_scan:show[YYYY-MM-DD]" unless args[:date]
    out_dir = "#{LeadScan::SCAN_ROOT}/shows/#{args[:date]}"
    exit 1 unless LeadScan.run([ "--show", args[:date] ], out_dir)
  end

  desc "Scan one year of shows (rake lead_scan:year[1996])"
  task :year, [ :year ] => :environment do |_t, args|
    abort "Usage: rake lead_scan:year[YYYY]" unless args[:year]
    out_dir = "#{LeadScan::SCAN_ROOT}/#{args[:year]}"
    ok = LeadScan.run(
      [ "--year", args[:year] ],
      out_dir,
      log_path: "#{LeadScan::SCAN_ROOT}/#{args[:year]}.log"
    )
    LeadScan.write_index
    exit 1 unless ok
  end

  desc "Regenerate the index page linking all year reports (data/lead_scan/index.html)"
  task :index do
    LeadScan.write_index
  end

  desc "Serve review pages with live trim previews (rake lead_scan:serve for all " \
       "years, or lead_scan:serve[2025] for one)"
  task :serve, [ :year, :port ] => :environment do |_t, args|
    dir = args[:year] ? "#{LeadScan::SCAN_ROOT}/#{args[:year]}" : LeadScan::SCAN_ROOT
    if args[:year] && !File.exist?("#{dir}/review.html")
      abort "No review page at #{dir}/review.html"
    end
    cmd = [ "uv", "run", "scripts/lead_scan_server.py", "--dir", dir ]
    cmd += [ "--port", args[:port] ] if args[:port]
    system(*cmd)
  end

  desc "Regenerate review pages from existing reports (rake lead_scan:rebuild or " \
       "lead_scan:rebuild[2025]); no audio analyzed. ONLY_UNREVIEWED=1 keeps just the " \
       "candidates you have not been through yet"
  task :rebuild, [ :year ] do |_t, args|
    dirs =
      if args[:year]
        [ "#{LeadScan::SCAN_ROOT}/#{args[:year]}" ].select { |d| File.exist?("#{d}/report.json") }
      else
        Dir.glob("#{LeadScan::SCAN_ROOT}/{[0-9][0-9][0-9][0-9],shows/*}")
           .select { |d| File.exist?("#{d}/report.json") }
      end
    abort "No reports found under #{LeadScan::SCAN_ROOT}" if dirs.empty?
    cmd = [ "uv", "run", LeadScan::SCAN_SCRIPT, *LeadScan::TUNING_FLAGS ] +
          dirs.flat_map { |d| [ "--rebuild", d ] }
    cmd << "--only-unreviewed" if ENV["ONLY_UNREVIEWED"] == "1"
    system(*cmd) || abort("Rebuild failed")
    LeadScan.write_index
  end

  desc "Scan a range of years (rake lead_scan:all or lead_scan:all[1994,1999])"
  task :all, [ :start_year, :end_year ] => :environment do |_t, args|
    start_year = (args[:start_year] || 1983).to_i
    end_year = (args[:end_year] || Time.zone.today.year).to_i
    failed = []

    (start_year..end_year).each do |year|
      puts "\n==== #{year} ===="
      out_dir = "#{LeadScan::SCAN_ROOT}/#{year}"
      ok = LeadScan.run(
        [ "--year", year.to_s ],
        out_dir,
        log_path: "#{LeadScan::SCAN_ROOT}/#{year}.log"
      )
      failed << year unless ok
    end

    LeadScan.write_index

    if failed.any?
      puts "\nYears with failures: #{failed.join(', ')}"
      exit 1
    else
      puts "\nAll years complete. Reports under #{LeadScan::SCAN_ROOT}/<year>/review.html"
    end
  end

  desc "Apply approved lead-in trims (rake lead_scan:apply[path/to/approved.json]); DRY_RUN=1 renders only, ONLY=<track url> filters"
  task :apply, [ :json_path ] => :environment do |_t, args|
    abort "Usage: rake lead_scan:apply[path/to/approved.json]" unless args[:json_path]
    entries = JSON.parse(File.read(args[:json_path]))

    if ENV["ONLY"].present?
      track = Track.by_url(ENV["ONLY"])
      abort "No track found for #{ENV['ONLY']} (expected a track url like https://phish.in/1996-11-02/sweet-adeline)" unless track
      position_token = format(" t%02d ", track.position)
      entries = entries.select do |e|
        e["label"].start_with?("#{track.show.date} ") && e["label"].include?(position_token)
      end
    end

    abort "No matching entries" if entries.empty?

    dry_run = ENV["DRY_RUN"] == "1"
    puts dry_run ? "DRY RUN: rendering trims without replacing audio\n\n" : "Applying #{entries.size} trim(s)\n\n"
    applied = 0
    failures = []

    entries.each_with_index do |entry, idx|
      label = entry["label"]
      progress = "[#{idx + 1}/#{entries.size}]"
      if entry["trim_start"].blank?
        failures << [ label, "no trim_start (render was skipped during scan)" ]
        next
      end

      key = File.basename(URI.parse(entry["mp3_url"]).path, ".mp3")
      blob = ActiveStorage::Blob.find_by(key:)
      attachment = blob && ActiveStorage::Attachment.find_by(
        blob_id: blob.id, record_type: "Track", name: "mp3_audio"
      )
      unless attachment
        failures << [ label, "blob #{key} not found (audio replaced since scan?)" ]
        next
      end

      begin
        result = AudioEdgeTrimService.call(
          attachment.record,
          trim_start: entry["trim_start"].to_f,
          trim_end: entry["trim_end"].to_f,
          fade_in: entry.fetch("fade_in", LeadScan::FADE_IN).to_f,
          fade_out: entry.fetch("fade_out", 0.0).to_f,
          # MIN_CUT screens candidates during the scan. By the time an entry is
          # in approved.json a human has picked its start time, so enforcing a
          # minimum here would just reject deliberate small trims.
          min_cut: 0.0,
          dry_run:
        )
        applied += 1
        track = attachment.record
        share_url = entry["share_url"].presence || "https://phish.in/#{track.show.date}/#{track.slug}"
        status = result[:applied] ? "APPLIED" : "RENDERED"
        display = label.sub(/\A(\d{4}-\d{2}-\d{2} .*?) t\d+ /, '\1 ')
        puts "#{status} #{progress}  #{display}: kept #{result[:kept_s]}s, cut #{result[:cut_s]}s"
        puts "  track:   #{share_url}"
        puts "  listen:  #{result[:output_path]}"
        puts "  backup:  #{result[:backup_path]}" if result[:backup_path]
      rescue AudioEdgeTrimService::Error => e
        failures << [ label, e.message ]
      end
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
