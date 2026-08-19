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

  # One review page for every year's candidates, written to the scan root as
  # index.html. Replaces the old year-listing index now that few candidates
  # remain; each year keeps its own report.json, so a single-year rescan still
  # works and this just re-merges them.
  def self.combine
    unless system("which uv > /dev/null 2>&1")
      abort "uv not found. Install it first: https://docs.astral.sh/uv/"
    end
    system("uv", "run", SCAN_SCRIPT, "--combine", SCAN_ROOT,
           "--ignore-file", "#{SCAN_ROOT}/ignore.txt") ||
      abort("Combine failed")
  end

  def self.resolve_track(entry)
    key = File.basename(URI.parse(entry["mp3_url"]).path, ".mp3")
    blob = ActiveStorage::Blob.find_by(key:)
    attachment = blob && ActiveStorage::Attachment.find_by(
      blob_id: blob.id, record_type: "Track", name: "mp3_audio"
    )
    return [ nil, "blob #{key} not found (audio replaced since scan?)" ] unless attachment
    [ attachment.record, nil ]
  end

  def self.prompt_for_song(part_title, label)
    unless $stdin.tty?
      puts "  no song matches #{part_title.inspect} (not a tty, skipping)"
      return nil
    end

    puts "\n  No song matches #{part_title.inspect} in #{label}"
    print "  Enter a song id, or press enter to skip: "

    answer = $stdin.gets.to_s.strip
    return nil if answer.empty?

    song = Song.find_by(id: answer.to_i)
    unless song
      puts "  No song found for #{answer.inspect}, skipping"
      return nil
    end
    puts "  Using #{song.title} (id=#{song.id})"
    song.id
  end

  # An entry carries its own cut points, part titles and song ids; the reviewer
  # set them all on the review page.
  def self.split_with_prompts(track, entry, dry_run, label)
    overrides = {}
    asked = Set.new
    cut_points = Array(entry["cut_points"]).map(&:to_f)
    begin
      TrackSplitService.call(
        track, cut_points:, dry_run:,
        song_overrides: overrides,
        tag_sides: entry["tag_sides"] || {},
        part_titles: entry["part_titles"],
        song_ids: entry["song_ids"]
      )
    rescue TrackSplitService::SongNotFoundError => e
      part = e.part_title
      raise if part.nil? || asked.include?(part.downcase)
      asked << part.downcase
      song_id = prompt_for_song(part, label)
      return nil if song_id.nil?
      overrides[part] = song_id
      retry
    end
  end

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
    SplitScan.combine
    exit 1 unless ok
  end

  desc "Rebuild the combined review page (data/split_scan/index.html)"
  task :index do
    SplitScan.combine
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
    SplitScan.combine
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
        result = SplitScan.split_with_prompts(track, entry, dry_run, label)
        next failures << [ label, "skipped: unmatched song" ] if result.nil?
        applied += 1
        status = result[:applied] ? "APPLIED" : "RENDERED"
        display = label.sub(/\A(\d{4}-\d{2}-\d{2} .*?) t\d+ /, '\1 ')
        puts "#{status} #{progress}  #{display}"
        result[:parts].each_with_index do |part, i|
          puts "  part #{i + 1}:  #{part[:title]} (#{part[:duration_s]}s) " \
               "-> #{part[:path]}"
        end
        puts "  backup:  #{result[:backup_path]}" if result[:backup_path]
        if result[:applied]
          result[:parts].each_with_index do |part, i|
            puts "  #{i.zero? ? 'tracks: ' : '        '} #{part[:url]}"
          end
          puts "  moved:   #{result[:likes_copied]} like(s), " \
               "#{result[:tags_copied]} tag(s), " \
               "#{result[:playlist_entries]} playlist entr(ies)"
          if result[:tags_removed].to_i.positive?
            puts "  removed: #{result[:tags_removed]} tag(s) set to neither"
          end
          if entry["tag_sides"].present?
            entry["tag_sides"].each { |name, side| puts "  tag:     #{name} -> #{side}" }
          end
          result[:reslugged].each do |r|
            puts "  reslug:  #{r[:from]} -> #{r[:to]} (track #{r[:track_id]})"
          end
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
