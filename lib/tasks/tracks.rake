namespace :tracks do
  desc "Find shows whose track positions regress to an earlier set (breaks player order)"
  task audit_set_order: :environment do
    set_ranks = SET_NAMES.keys.each_with_index.to_h

    rows = Track.joins(:show)
                .order("shows.date", :position)
                .pluck(Arel.sql("shows.date"), :show_id, :position, :set, :title)

    flagged = 0
    rows.group_by { |date, _| date }.each do |date, tracks|
      unknown = tracks.reject { |_, _, _, set, _| set_ranks.key?(set) }
      if unknown.any?
        puts "#{date}: unknown set value(s): #{unknown.map { |t| "#{t[4]} (set=#{t[3].inspect})" }.join(', ')}"
        flagged += 1
        next
      end

      regressions = tracks.each_cons(2).select do |(_, _, _, prev_set, _), (_, _, _, set, _)|
        set_ranks[set] < set_ranks[prev_set]
      end
      next if regressions.none?

      flagged += 1
      puts date
      regressions.each do |(_, _, prev_pos, prev_set, prev_title), (_, _, pos, set, title)|
        puts "  position #{prev_pos} #{prev_title} (#{SET_NAMES[prev_set]}) is followed by " \
             "position #{pos} #{title} (#{SET_NAMES[set]})"
      end
    end

    puts flagged.zero? ? "No set order problems found." : "\n#{flagged} show(s) flagged."
  end

  desc "Populate song performance gaps"
  task populate_gaps: :environment do
    rel = Show.published.order(date: :asc)
    pbar = ProgressBar.create(
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"
    )

    rel.each do |show|
      GapService.call(show)
      pbar.increment
    end

    pbar.finish
  end

  desc "Regenerate waveform images (resizing)"
  task generate_images: :environment do
    relation = Track.select(:id)
    pbar = ProgressBar.create(
      total: relation.count,
      format: "%a %B %c/%C %p%% %E"
    )

    relation.find_each do |track|
      RegenerateTrackWaveformJob.perform_async(track.id)
      pbar.increment
    end

    pbar.finish
  end

  desc "Report tracks whose MP3 files have no embedded album art (set FIX=true to retag them)"
  task audit_album_art: :environment do
    fix = ENV["FIX"] == "true"
    relation = Track.with_audio
                    .joins(:mp3_audio_attachment)
                    .includes(:show, mp3_audio_attachment: :blob)

    pbar = ProgressBar.create(
      total: relation.count,
      format: "%a %B %c/%C %p%% %E"
    )

    missing = []
    unreadable = []

    relation.find_each do |track|
      case Id3AlbumArtChecker.call(track)
      when :missing then missing << track
      when :unreadable then unreadable << track
      end

      pbar.increment
    end

    pbar.finish

    puts "\nTracks missing embedded album art: #{missing.size}"
    missing.first(50).each { |t| puts "  #{t.show.date} #{t.position} #{t.title} (id #{t.id})" }
    puts "  ...and #{missing.size - 50} more" if missing.size > 50

    if unreadable.any?
      puts "\nTracks whose MP3 could not be read: #{unreadable.size}"
      unreadable.first(50).each { |t| puts "  #{t.show.date} #{t.position} #{t.title} (id #{t.id})" }
    end

    next unless fix && missing.any?

    puts "\nRe-applying ID3 tags to #{missing.size} tracks..."
    fix_bar = ProgressBar.create(total: missing.size, format: "%a %B %c/%C %p%% %E")
    still_missing = []

    missing.each do |track|
      track.apply_id3_tags
      # apply_id3_tags re-attaches a new blob, so re-read the track before
      # re-checking rather than trusting the stale in-memory attachment.
      still_missing << track if Id3AlbumArtChecker.call(Track.find(track.id)) != :present
      fix_bar.increment
    end

    fix_bar.finish

    puts "Repaired: #{missing.size - still_missing.size}"
    next if still_missing.empty?

    puts "Still missing after retagging: #{still_missing.size}"
    still_missing.first(50).each { |t| puts "  #{t.show.date} #{t.position} #{t.title} (id #{t.id})" }
  end

  desc "Reset MP3 filenames on blobs to friendly download format"
  task reset_mp3_filenames: :environment do
    relation = Track.joins(:mp3_audio_attachment)
                    .includes(:show, mp3_audio_attachment: :blob)

    pbar = ProgressBar.create(
      total: relation.count,
      format: "%a %B %c/%C %p%% %E"
    )

    relation.find_each do |track|
      friendly = track.friendly_filename

      if track.mp3_audio.attached? && track.mp3_audio.blob.filename.to_s != friendly
        track.mp3_audio.blob.update!(filename: friendly)
      end

      pbar.increment
    end

    pbar.finish
  end
end
