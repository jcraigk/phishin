require "shellwords"

# Finds banter tracks the taper notes list but the show lacks, resolves the
# archive.org source the show was cut from, and audits the joints on either
# side of the source's banter file so the placement is proven by audio
# continuity before anything is inserted. Same scan/review/apply shape as
# sandwich_scan.
module BanterScan
  SCAN_SCRIPT = "scripts/audio_banter_analysis.py".freeze
  SCAN_ROOT = "data/banter_scan".freeze

  def self.run(extra = [])
    unless system("which uv > /dev/null 2>&1")
      abort "uv not found. Install it first: https://docs.astral.sh/uv/"
    end

    cmd = [
      "uv", "run", SCAN_SCRIPT,
      "--out-dir", SCAN_ROOT,
      *extra
    ]
    cmd.concat(Shellwords.split(ENV["EXTRA"])) if ENV["EXTRA"].present?

    puts "Running: #{Shellwords.join(cmd)}"
    ok = system(*cmd)
    puts ok ? "Done. Review: #{SCAN_ROOT}/review.html" : "FAILED (see output above)"
    ok
  end

  # The review export names the archive.org item and file for every entry, so
  # apply can pull the FLAC itself instead of needing it uploaded alongside.
  def self.fetch_source(item, file, dest)
    raise "no archive.org item in the export" if item.blank? || file.blank?
    raise "local sources (#{item}) must be uploaded" if item.start_with?("local:")

    url = "https://archive.org/download/#{item}/#{file}"
    puts "  fetching #{url}"
    FileUtils.mkdir_p(File.dirname(dest))
    tmp = "#{dest}.part"
    3.times do |attempt|
      # archive.org mirrors throw intermittent 5xx; a retry lands elsewhere.
      break if system("curl", "-sfL", "--retry", "2", "-o", tmp, url)
      raise "download failed after 3 attempts" if attempt == 2
    end
    File.rename(tmp, dest)
    dest
  end
end

namespace :banter_scan do
  desc "Scan taper notes for missing banter and audit source joints " \
       "(rake banter_scan:run, or banter_scan:run[1991-05-17,1992-11-20] for given shows)"
  task :run, [ :dates ] => :environment do |_t, args|
    extra = args[:dates] ? [ "--dates", args[:dates] ] : [ "--from-notes" ]
    exit 1 unless BanterScan.run(extra)
  end

  desc "Regenerate the review page from the existing report.json"
  task rebuild: :environment do
    exit 1 unless BanterScan.run([ "--rebuild" ])
  end

  desc "Insert approved banter tracks (rake banter_scan:apply[path/to/approved.json]); " \
       "DRY_RUN=1 renders only, DATE=YYYY-MM-DD applies one show, " \
       "SOURCE_DIR=/dir resolves source files as <dir>/<date>/<file> (for prod uploads)"
  task :apply, [ :json_path ] => :environment do |_t, args|
    abort "Usage: rake banter_scan:apply[path/to/approved.json]" unless args[:json_path]
    entries = JSON.parse(File.read(args[:json_path]))
    abort "No entries" if entries.empty?

    if ENV["DATE"].present?
      entries = entries.select { it["date"] == ENV["DATE"] }
      abort "No entries for #{ENV['DATE']}" if entries.empty?
    end

    dry_run = ENV["DRY_RUN"] == "1"
    puts dry_run ? "DRY RUN: rendering without changing anything\n\n"
                 : "Inserting #{entries.size} banter track(s)\n\n"
    failures = []

    # Later positions first, so an insert never shifts an anchor that a
    # following entry in the same show still refers to by position.
    entries.sort_by { [ it["date"], -(it["after_position"] || it["before_position"]).to_i ] }.each_with_index do |entry, idx|
      progress = "[#{idx + 1}/#{entries.size}]"
      label = entry["after_id"] ? "#{entry['date']} after #{entry['after_title']}" \
                                : "#{entry['date']} before #{entry['before_title']}"
      after_track = entry["after_id"] && Track.find_by(id: entry["after_id"])
      before_track = entry["before_id"] && Track.find_by(id: entry["before_id"])
      if (entry["after_id"] && after_track.nil?) || (entry["before_id"] && before_track.nil?)
        next failures << [ label, "anchor track not found" ]
      end
      # A run exports several files; insert them last file first at the same
      # slot so each push lands the previous one further down, in source order.
      members = entry["members"].presence || [ entry ]
      members.reverse.each do |member|
        member_path = member["source_path"] || entry["source_path"]
        if ENV["SOURCE_DIR"].present?
          member_path = File.join(ENV["SOURCE_DIR"], entry["date"], File.basename(member_path))
        end
        unless File.exist?(member_path)
          begin
            BanterScan.fetch_source(entry["source_item"], member["source_file"], member_path)
          rescue StandardError => e
            next failures << [ label, "could not fetch #{member['source_file']}: #{e.message}" ]
          end
        end
        song = member["song_id"] ? Song.find_by(id: member["song_id"]) : nil
        next failures << [ label, "song #{member['song_id']} not found" ] if member["song_id"] && song.nil?

        begin
          result = BanterInsertService.call(
            after_track,
            before_track:,
            source_path: member_path,
            title: member["title"].presence || "Banter",
            **(song ? { song: } : {}),
            set: entry["set"].presence,
            dry_run:
          )
          status = result[:applied] ? "INSERTED" : "RENDERED"
          puts "#{status} #{progress}  #{label}  as ##{result[:position]} #{result[:title]} (#{result[:song]})"
          puts "  output: #{result[:output_path]}"
          puts "  track:  #{result[:url]}" if result[:applied]
          before_track = Track.find(result[:track_id]) if result[:applied] && members.size > 1
        rescue BanterInsertService::Error, RuntimeError => e
          failures << [ label, e.message ]
        end
      end
    end

    Rails.cache.clear unless dry_run
    next if failures.empty?

    puts "\n#{failures.size} failure(s):"
    failures.each { |label, msg| puts "  #{label}: #{msg}" }
  end
end
