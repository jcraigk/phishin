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

  desc "Diagnose why specific tracks are missing album art (IDS=253,275,330)"
  task diagnose_album_art: :environment do
    ids = ENV["IDS"].to_s.split(",").map(&:strip).reject(&:empty?)
    if ids.empty?
      puts "Provide track ids, e.g. IDS=253,275,330"
      next
    end

    puts "storage service: #{ActiveStorage::Blob.service.class}"

    Track.where(id: ids).includes(:show).find_each do |track|
      show = track.show
      puts "\ntrack #{track.id} #{show.date} #{track.title}"
      puts "  audio_status=#{track.audio_status}"
      puts "  mp3_attached=#{track.mp3_audio.attached?}"

      if track.mp3_audio.attached?
        blob = track.mp3_audio.blob
        path = ActiveStorage::Blob.service.path_for(blob.key)
        puts "  mp3_file_exists=#{File.exist?(path)} db_byte_size=#{blob.byte_size}"
        puts "  mp3_path=#{path}"
      end

      puts "  album_cover_attached=#{show.album_cover.attached?}"
      if show.album_cover.attached?
        cover_path = ActiveStorage::Blob.service.path_for(show.album_cover.blob.key)
        puts "  cover_file_exists=#{File.exist?(cover_path)}"
      end

      puts "  checker=#{Id3AlbumArtChecker.call(track)}"

      begin
        Id3TagService.new(track).send(:temp_audio_file_path)
        puts "  download=OK"
      rescue StandardError => e
        puts "  download RAISED #{e.class}: #{e.message}"
      end

      next unless track.mp3_audio.attached?

      path = ActiveStorage::Blob.service.path_for(track.mp3_audio.blob.key)
      header = File.binread(path, 10).to_s
      puts "  first3=#{header[0, 3].inspect} version=2.#{header.getbyte(3)}.#{header.getbyte(4)}"
      size_bytes = header[6, 4].to_s.unpack("C4")
      puts "  size_bytes=#{size_bytes.inspect} syncsafe_ok=#{size_bytes.compact.none? { |b| b > 0x7f }}"

      require "mp3info"
      begin
        Mp3Info.open(path) do |mp3|
          puts "  mp3info_v2_present=#{mp3.hastag2?} frames=#{mp3.tag2.keys.sort.join(',')}"
          puts "  mp3info_pictures=#{mp3.tag2.pictures.size}"
        end
      rescue StandardError => e
        puts "  mp3info RAISED #{e.class}: #{e.message}"
      end

      # Does the APIC bytestring appear anywhere in the first 4MB?
      head = File.binread(path, 4_000_000).to_s
      puts "  apic_in_head=#{head.include?('APIC')} at=#{head.index('APIC').inspect}"
    end
  end

  desc "Diagnose the :id3 album cover variant for a show (DATE=1987-04-29)"
  task diagnose_variant: :environment do
    show = Show.find_by!(date: ENV.fetch("DATE"))
    cover = show.album_cover

    puts "show #{show.date} cover_attached=#{cover.attached?}"
    blob = cover.blob
    puts "blob key=#{blob.key} content_type=#{blob.content_type} byte_size=#{blob.byte_size}"
    puts "analyzed=#{blob.analyzed?} metadata=#{blob.metadata.inspect}"

    src = ActiveStorage::Blob.service.path_for(blob.key)
    puts "source_exists=#{File.exist?(src)} actual_size=#{File.exist?(src) ? File.size(src) : 'n/a'}"
    puts "magic_bytes=#{File.binread(src, 4).unpack1('H*')}" if File.exist?(src)

    puts "variant_processor=#{Rails.application.config.active_storage.variant_processor}"
    puts "imagemagick=#{`which convert magick 2>/dev/null`.strip.inspect}"

    variant = cover.variant(:id3)
    begin
      processed = variant.processed
      puts "processed_ok key=#{processed.key}"
      puts "variant_service_exists=#{ActiveStorage::Blob.service.exist?(processed.key)}"
      data = processed.download
      puts "download_bytes=#{data&.bytesize.inspect}"
    rescue StandardError => e
      puts "VARIANT RAISED #{e.class}: #{e.message}"
      puts e.backtrace.first(8)
    end
  end

  desc "Retag a single track with full error output (IDS=253)"
  task retag_one: :environment do
    track = Track.find(ENV.fetch("IDS").split(",").first)
    show = track.show

    puts "track #{track.id} #{show.date} #{track.title}"
    puts "before_checker=#{Id3AlbumArtChecker.call(track)}"
    puts "key_before=#{track.mp3_audio.blob.key}"
    puts "cover_attached=#{show.album_cover.attached?}"

    begin
      variant = show.album_cover.variant(:id3).processed
      data = variant.download
      puts "variant_bytes=#{data&.bytesize.inspect}"
    rescue StandardError => e
      puts "VARIANT RAISED #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
    end

    begin
      Id3TagService.call(track)
      puts "tag_service=completed"
    rescue StandardError => e
      puts "TAG SERVICE RAISED #{e.class}: #{e.message}"
      puts e.backtrace.first(5)
    end

    fresh = Track.find(track.id)
    puts "key_after=#{fresh.mp3_audio.blob.key}"
    puts "after_checker=#{Id3AlbumArtChecker.call(fresh)}"

    path = ActiveStorage::Blob.service.path_for(fresh.mp3_audio.blob.key)
    puts "file_exists=#{File.exist?(path)}"
    require "mp3info"
    Mp3Info.open(path) { |mp3| puts "pictures_after=#{mp3.tag2.pictures.size}" }
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
