require "shellwords"

# Finds the Fall 1995 band/audience chess-match banter still embedded in song
# tracks and splits it into its own track. The scan (audio_chess_analysis.py)
# transcribes on-mic speech at set openers and the tracks the taper notes
# single out; the review page picks a cut and a title; apply splits the track
# with TrackSplitService and tags the chess part as Banter. Same scan/review/
# apply shape as split_scan, whose track resolution and gap refresh it reuses.
module ChessScan
  SCAN_SCRIPT = "scripts/audio_chess_analysis.py".freeze
  SCAN_ROOT = "data/chess_scan".freeze
  CHESS_SONG_TITLE = "Audience Chess Move".freeze
  # Untimestamped tags that describe the recording rather than the song, so
  # both halves of a split keep them. Everything else stays with the song.
  RECORDING_TAGS = %w[SBD RMSTR Audience CUT].freeze

  class Error < StandardError; end

  def self.run(extra = [])
    unless system("which uv > /dev/null 2>&1")
      abort "uv not found. Install it first: https://docs.astral.sh/uv/"
    end

    cmd = [ "uv", "run", SCAN_SCRIPT, "--out-dir", SCAN_ROOT, *extra ]
    cmd.concat(Shellwords.split(ENV["EXTRA"])) if ENV["EXTRA"].present?

    puts "Running: #{Shellwords.join(cmd)}"
    ok = system(*cmd)
    puts ok ? "Done. Review: #{SCAN_ROOT}/review.html" : "FAILED (see output above)"
    ok
  end

  # What TrackSplitService needs for one approved entry. The review page (the
  # split scan's) exports part_titles and song_ids for both parts; the chess
  # part is the one carrying the chess song, and it is the only part that
  # gets the Banter tag. Recording-wide tags stay on both parts, song tags on
  # the song part, unless the reviewer chose sides on the page.
  def self.plan(entry, track)
    chess_song = Song.find_by(title: CHESS_SONG_TITLE)
    raise Error, "no song titled #{CHESS_SONG_TITLE.inspect}" unless chess_song

    titles = Array(entry["part_titles"]).map(&:to_s)
    ids = Array(entry["song_ids"]).map { it&.to_i }
    raise Error, "expected two parts, got #{titles.inspect}" unless titles.size == 2 && ids.size == 2

    chess_index = ids.index(chess_song.id) || titles.index { it.match?(/chess/i) }
    raise Error, "neither part is the chess move: #{titles.inspect}" unless chess_index

    ids[chess_index] = chess_song.id
    song_index = 1 - chess_index
    ids[song_index] ||= track.songs.first&.id
    raise Error, "#{track.url} has no song for #{titles[song_index].inspect}" unless ids[song_index]

    tag_sides = track.track_tags.includes(:tag).each_with_object({}) do |tt, sides|
      next unless tt.starts_at_second.nil? && tt.ends_at_second.nil?

      name = tt.tag.name
      sides[name] = RECORDING_TAGS.include?(name) ? [ 0, 1 ] : [ song_index ]
    end
    tag_sides.merge!(entry["tag_sides"] || {})

    {
      cut_points: Array(entry["cut_points"]).map(&:to_f),
      part_titles: titles,
      song_ids: ids,
      tag_sides:,
      chess_index:
    }
  end

  # Tracks titled as chess moves but linked to the generic Banter song (three
  # 1995 shows were imported that way) get the chess song and the canonical
  # title. Returns the tracks it changed.
  def self.relink(scope)
    chess_song = Song.find_by!(title: CHESS_SONG_TITLE)
    scope.where("title ILIKE ?", "%chess%").includes(:songs).filter_map do |track|
      next if track.songs.map(&:id) == [ chess_song.id ]

      track.songs = [ chess_song ]
      track.update!(title: CHESS_SONG_TITLE)
      track
    end
  end

  def self.tag_chess_part(result, track, notes)
    part_track = result[:chess_index].zero? ? track : Track.find(result[:new_track_ids].first)
    banter = Tag.find_by!(name: "Banter")
    return if part_track.track_tags.exists?(tag: banter)

    part_track.track_tags.create!(tag: banter, notes: notes.presence)
  end
end

namespace :chess_scan do
  desc "Scan Fall 1995 shows for chess-match banter (rake chess_scan:run or " \
       "chess_scan:run[1995-09-30,1995-12-05]); EXTRA='--all' scans every track"
  task :run, [ :dates ] => :environment do |_t, args|
    dates = [ args[:dates], *args.extras ].compact
    extra = dates.any? ? [ "--date", dates.join(",") ] : []
    exit 1 unless ChessScan.run(extra)
  end

  desc "Regenerate the review page from the existing report.json"
  task rebuild: :environment do
    exit 1 unless ChessScan.run([ "--rebuild" ])
  end

  desc "Serve the review page with live cut previews (rake chess_scan:serve or chess_scan:serve[8765])"
  task :serve, [ :port ] => :environment do |_t, args|
    abort "No review page at #{ChessScan::SCAN_ROOT}/review.html" unless File.exist?("#{ChessScan::SCAN_ROOT}/review.html")
    cmd = [ "uv", "run", "scripts/lead_scan_server.py", "--dir", ChessScan::SCAN_ROOT ]
    cmd += [ "--port", args[:port] ] if args[:port]
    system(*cmd)
  end

  desc "Retitle chess tracks linked to the generic Banter song and link the chess song " \
       "(rake chess_scan:relink); DRY_RUN=1 lists only"
  task relink: :environment do
    scope = Track.joins(:show).where(shows: { date: Date.new(1995, 9, 1)..Date.new(1995, 12, 31) })
    if ENV["DRY_RUN"] == "1"
      chess_song = Song.find_by!(title: ChessScan::CHESS_SONG_TITLE)
      scope.where("tracks.title ILIKE ?", "%chess%").includes(:songs, :show).each do |t|
        next if t.songs.map(&:id) == [ chess_song.id ]

        puts "would relink #{t.url} (#{t.title}; #{t.songs.map(&:title).join(', ')})"
      end
      next
    end
    changed = ChessScan.relink(scope)
    changed.each { puts "relinked #{it.url}" }
    puts "#{changed.size} track(s) relinked"
    Rails.cache.clear if changed.any?
  end

  desc "Split approved chess banter out of its track (rake chess_scan:apply[path/to/approved.json]); " \
       "DRY_RUN=1 renders only, DATE=YYYY-MM-DD applies one show"
  task :apply, [ :json_path ] => :environment do |_t, args|
    abort "Usage: rake chess_scan:apply[path/to/approved.json]" unless args[:json_path]
    entries = JSON.parse(File.read(args[:json_path]))
    entries = entries.select { it["label"].to_s.start_with?(ENV["DATE"]) } if ENV["DATE"].present?
    abort "No entries" if entries.empty?

    dry_run = ENV["DRY_RUN"] == "1"
    puts dry_run ? "DRY RUN: rendering both parts without changing anything\n\n"
                 : "Applying #{entries.size} split(s)\n\n"
    applied = 0
    failures = []
    touched = Hash.new { |h, k| h[k] = [] }

    entries.each_with_index do |entry, idx|
      label = entry["label"]
      progress = "[#{idx + 1}/#{entries.size}]"
      if Array(entry["cut_points"]).empty?
        failures << [ label, "no cut_points in the export" ]
        next
      end

      track, error = SplitScan.resolve_track(entry)
      if error
        failures << [ label, error ]
        next
      end

      begin
        plan = ChessScan.plan(entry, track)
        result = TrackSplitService.call(
          track, cut_points: plan[:cut_points], dry_run:,
          tag_sides: plan[:tag_sides], part_titles: plan[:part_titles], song_ids: plan[:song_ids]
        )
        result[:chess_index] = plan[:chess_index]
        applied += 1
        puts "#{result[:applied] ? 'APPLIED' : 'RENDERED'} #{progress}  #{label}"
        result[:parts].each_with_index do |part, i|
          puts "  part #{i + 1}:  #{part[:title]} (#{part[:duration_s]}s) -> #{part[:path]}"
        end
        puts "  backup:  #{result[:backup_path]}" if result[:backup_path]
        next unless result[:applied]

        ChessScan.tag_chess_part(result, track, entry["notes"])
        result[:parts].each_with_index do |part, i|
          puts "  #{i.zero? ? 'tracks: ' : '        '} #{part[:url]}"
        end
        result[:reslugged].each { puts "  reslug:  #{it[:from]} -> #{it[:to]} (track #{it[:track_id]})" }
        result[:notes].each { puts "  note:    #{it}" }
        touched[track.show] |= result[:song_ids].map { Song.find(it) }
      rescue TrackSplitService::Error, ChessScan::Error => e
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
