namespace :tracks do
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
    missing.each do |track|
      track.apply_id3_tags
      fix_bar.increment
    end
    fix_bar.finish
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
