require "shellwords"

# Undoes one sandwich merge: puts the original tracks back from their audio
# files, restoring the record that was rewritten and recreating the ones that
# were destroyed. The merge is not reversible from the merged audio alone, so
# the original mp3s have to be supplied.
namespace :sandwich_scan do
  desc "Restore a merged sandwich from its original files " \
       "(rake sandwich_scan:restore[1991-11-14,/content/import]); " \
       "TRACK_ID=<id> names the merged track, DRY_RUN=1 reports only"
  task :restore, [ :date, :dir ] => :environment do |_t, args|
    abort "Usage: rake sandwich_scan:restore[YYYY-MM-DD,/path/to/files]" unless args[:date] && args[:dir]
    dry_run = ENV["DRY_RUN"] == "1"

    show = Show.find_by(date: args[:date]) || abort("No show on #{args[:date]}")
    merged =
      if ENV["TRACK_ID"].present?
        Track.find_by(id: ENV["TRACK_ID"]) || abort("No track #{ENV['TRACK_ID']}")
      else
        abort "TRACK_ID=<id> is required (the merged track to replace)"
      end
    abort "Track #{merged.id} is not in #{show.date}" unless merged.show_id == show.id

    files = Dir.glob("#{args[:dir]}/*.mp3").sort
    abort "No mp3 files in #{args[:dir]}" if files.empty?
    puts "Restoring #{show.date} position #{merged.position} " \
         "(#{merged.title.inspect}) from #{files.size} file(s):"
    files.each { puts "  #{File.basename(it)}" }
    puts

    # The merged track keeps position and id; the rest are inserted after it and
    # everything below moves back down to make room.
    tail = show.tracks.where("position > ?", merged.position).order(:position).to_a
    shift = files.size - 1
    puts "Would shift #{tail.size} later track(s) down by #{shift}"

    titles = files.map do |path|
      File.basename(path, ".mp3").sub(/\APhish \d{4}-\d{2}-\d{2} \d+ /, "")
    end
    titles.each_with_index do |t, i|
      puts "  part #{i + 1}: #{t.inspect} -> position #{merged.position + i}"
    end

    if dry_run
      puts "\nDRY RUN: nothing changed"
      next
    end

    # The records and their positions move in one transaction; the audio is
    # attached after it commits. ActiveStorage uploads the file in an
    # after_commit hook, so anything reading the file inside the transaction
    # finds no file on disk.
    restored = [ merged ]
    ActiveRecord::Base.transaction do
      # Two phase: park the tail beyond every position this restore will use, so
      # neither the shift nor the new records collide on (show_id, position).
      parking = show.tracks.maximum(:position).to_i + 100
      tail.each_with_index { |t, i| t.update!(position: parking + i) }

      merged.update!(title: titles.first, slug: "tmp-restore-#{merged.id}")
      merged.songs = [ Song.find_by("LOWER(title) = ?", titles.first.downcase) ].compact

      files.drop(1).each_with_index do |_path, i|
        title = titles[i + 1]
        track = Track.new(
          show:, title:, position: merged.position + i + 1,
          set: merged.set, slug: "tmp-restore-new-#{i}"
        )
        track.songs = [ Song.find_by("LOWER(title) = ?", title.downcase) ].compact
        track.save!
        restored << track
      end

      tail.each_with_index do |t, i|
        t.update!(position: merged.position + files.size + i)
      end
    end

    restored.each_with_index do |track, i|
      track.mp3_audio.attach(
        io: File.open(files[i]), filename: File.basename(files[i]),
        content_type: "audio/mpeg"
      )
      track.reload
      track.update!(slug: TrackSlugGenerator.call(track))
      track.process_mp3_audio
      puts "restored: #{track.title} (id #{track.id}, position #{track.position})"
    end

    show.reload.save_duration
    songs = show.tracks.reload.flat_map(&:songs).uniq
    puts "\nRecomputing gaps for #{show.date}..."
    GapService.call(show, update_previous: true, song_ids: songs.map(&:id))
    Rails.cache.clear
    puts "Done. #{show.tracks.count} tracks on #{show.date}"
  end
end
