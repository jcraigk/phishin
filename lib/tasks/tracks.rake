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

  desc "Write CSV of combined ('>') tracks with blank split-time columns to fill in"
  task :split_report, [ :csv_path ] => :environment do |_t, args|
    csv_path = args[:csv_path] || "#{Rails.root}/tmp/track_splits.csv"
    relation = Track.where("title LIKE '%>%'")
                    .where.not(set: "S")
                    .order(duration: :desc)
                    .includes(:show)
    max_splits = relation.map { |t| t.title.count(">") }.max || 0

    CSV.open(csv_path, "w") do |csv|
      csv << [ "Date", "Title", "Duration", "URL" ] +
             (1..max_splits).map { |n| "Split #{n}" }
      relation.each do |track|
        minutes, seconds = (track.duration / 1000).divmod(60)
        csv << [
          track.show.date,
          track.title,
          format("%d:%02d", minutes, seconds),
          track.url
        ] + Array.new(max_splits)
      end
    end

    puts "Wrote #{relation.size} tracks (max #{max_splits} splits) to #{csv_path}"
  end

  desc "Split combined tracks at times given in CSV (from split_report); DRY_RUN=1 to preview"
  task :split, [ :csv_path ] => :environment do |_t, args|
    raise "Usage: rake tracks:split[path/to/track_splits.csv]" if args[:csv_path].blank?
    dry_run = ENV["DRY_RUN"].present?
    results = { split: 0, skipped: 0, failed: 0 }

    CSV.foreach(args[:csv_path], headers: true) do |row|
      times = row.headers.grep(/\ASplit \d+\z/).filter_map { |h| row[h].presence }
      next results[:skipped] += 1 if times.empty?

      begin
        track = Track.by_url(row["URL"]) || raise("No track found at #{row['URL']}")
        split_at_seconds = times.map do |time|
          time.strip.split(":").map { |part| Integer(part, 10) }
              .reverse.each_with_index.sum { |value, i| value * 60**i }
        end
        result = TrackSplitter.call(track, split_at_seconds:, dry_run:)
        results[:split] += 1

        if dry_run
          puts "Would split #{track.url} into:"
          result.each do |segment|
            range = "#{segment[:starts_at]}s - #{segment[:ends_at] ? "#{segment[:ends_at]}s" : 'end'}"
            puts "  #{segment[:title]} (#{segment[:song].title}) [#{range}]"
          end
        else
          puts "Split #{row['URL']} into #{result.size} tracks"
        end
      rescue StandardError => e
        results[:failed] += 1
        puts "FAILED #{row['URL']}: #{e.message}"
      end
    end

    action = dry_run ? "previewed" : "split"
    puts "#{results[:split]} #{action}, #{results[:skipped]} skipped (no times), " \
         "#{results[:failed]} failed"
  end
end
