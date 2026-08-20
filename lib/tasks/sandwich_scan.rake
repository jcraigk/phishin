require "shellwords"

# Finds sandwiches ("HYHU > Terrapin > HYHU") that were stored as two adjacent
# tracks and should be one. Same scan/review/apply shape as split_scan, but the
# whole catalog produces a single report rather than one per year.
module SandwichScan
  SCAN_SCRIPT = "scripts/audio_sandwich_analysis.py".freeze
  SCAN_ROOT = "data/sandwich_scan".freeze

  def self.run(extra = [])
    unless system("which uv > /dev/null 2>&1")
      abort "uv not found. Install it first: https://docs.astral.sh/uv/"
    end

    cmd = [
      "uv", "run", SCAN_SCRIPT,
      "--ignore-file", "#{SCAN_ROOT}/ignore.txt",
      "--json", "#{SCAN_ROOT}/report.json",
      "--html", "#{SCAN_ROOT}/review.html",
      *extra
    ]
    cmd.concat(Shellwords.split(ENV["EXTRA"])) if ENV["EXTRA"].present?

    puts "Running: #{Shellwords.join(cmd)}"
    ok = system(*cmd)
    puts ok ? "Done. Review: #{SCAN_ROOT}/review.html" : "FAILED (see output above)"
    ok
  end

  def self.resolve_track(id, label)
    track = Track.find_by(id:)
    return [ nil, "track #{id} not found (#{label})" ] unless track
    [ track, nil ]
  end
end

namespace :sandwich_scan do
  desc "Scan for split sandwiches (rake sandwich_scan:run, or " \
       "sandwich_scan:run[1990-10-12] for one show)"
  task :run, [ :date ] => :environment do |_t, args|
    extra = args[:date] ? [ "--show", args[:date] ] : []
    exit 1 unless SandwichScan.run(extra)
  end

  desc "Regenerate the review page from the existing report.json"
  task rebuild: :environment do
    cmd = [ "uv", "run", SandwichScan::SCAN_SCRIPT,
            "--rebuild", SandwichScan::SCAN_ROOT,
            "--ignore-file", "#{SandwichScan::SCAN_ROOT}/ignore.txt" ]
    system(*cmd) || abort("Rebuild failed")
  end

  desc "Serve the review page with live joint previews " \
       "(rake sandwich_scan:serve[port])"
  task :serve, [ :port ] => :environment do |_t, args|
    unless File.exist?("#{SandwichScan::SCAN_ROOT}/review.html")
      abort "No review page at #{SandwichScan::SCAN_ROOT}/review.html - " \
            "run rake sandwich_scan:run first"
    end
    cmd = [ "uv", "run", "scripts/lead_scan_server.py",
            "--dir", SandwichScan::SCAN_ROOT ]
    cmd += [ "--port", args[:port] ] if args[:port]
    system(*cmd)
  end

  desc "Apply approved sandwich merges " \
       "(rake sandwich_scan:apply[path/to/approved.json]); DRY_RUN=1 renders only"
  task :apply, [ :json_path ] => :environment do |_t, args|
    abort "Usage: rake sandwich_scan:apply[path/to/approved.json]" unless args[:json_path]
    entries = JSON.parse(File.read(args[:json_path]))
    abort "No entries" if entries.empty?

    dry_run = ENV["DRY_RUN"] == "1"
    puts dry_run ? "DRY RUN: rendering merges without changing anything\n\n"
                 : "Merging #{entries.size} sandwich(es)\n\n"
    applied = 0
    failures = []
    touched = Hash.new { |h, k| h[k] = [] }

    entries.each_with_index do |entry, idx|
      label = entry["label"]
      progress = "[#{idx + 1}/#{entries.size}]"

      first, error = SandwichScan.resolve_track(entry["first_id"], label)
      next failures << [ label, error ] if error
      second, error = SandwichScan.resolve_track(entry["second_id"], label)
      next failures << [ label, error ] if error

      third = nil
      if entry["third_id"].present?
        third, error = SandwichScan.resolve_track(entry["third_id"], label)
        next failures << [ label, error ] if error
      end

      begin
        # A three-track sandwich is two merges: fold the middle in first, then
        # the tail. The service only ever joins an adjacent pair, and after the
        # first merge the tail has shifted down into place.
        result = TrackMergeService.call(
          first, second:, title: entry["merged_title"], dry_run:
        )
        if third && !dry_run
          result = TrackMergeService.call(
            first.reload, second: third.reload,
            title: entry["merged_title"], dry_run:
          )
        end
        applied += 1
        status = result[:applied] ? "MERGED" : "RENDERED"
        puts "#{status} #{progress}  #{entry['date']}  #{result[:title]}"
        puts "  parts:   #{result[:first_title]} (#{result[:first_duration_s]}s) + " \
             "#{result[:second_title]} (#{result[:second_duration_s]}s)"
        puts "  output:  #{result[:output_path]}"
        puts "  trimmed: 1ms of encoder flush off the end of " \
             "#{result[:first_title]}" if result[:tail_trimmed]
        puts "  trimmed: 1ms of encoder flush off the start of " \
             "#{result[:second_title]}" if result[:head_trimmed]
        puts "  backups: #{result[:backup_paths].join(', ')}" if result[:backup_paths].any?
        if result[:applied]
          puts "  track:   #{result[:url]}"
          puts "  moved:   #{result[:likes_moved]} like(s), " \
               "#{result[:tags_moved]} tag(s), " \
               "#{result[:playlist_entries]} playlist entr(ies)"
          result[:reslugged].each do |r|
            puts "  reslug:  #{r[:from]} -> #{r[:to]} (track #{r[:track_id]})"
          end
          result[:notes].each { puts "  note:    #{it}" }
          touched[first.show] |= result[:song_ids].map { Song.find(it) }
        end
      rescue TrackMergeService::Error => e
        failures << [ label, e.message ]
      end
    end

    touched.each do |show, songs|
      puts "\nRecomputing gaps for #{show.date}..."
      GapService.call(show, update_previous: true, song_ids: songs.map(&:id))
    end

    puts "\n#{applied} of #{entries.size} entries #{dry_run ? 'rendered' : 'merged'}"
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
