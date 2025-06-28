namespace :gaps do
  desc "Recalculate all gap data for all shows"
  task recalculate_all: :environment do
    puts "Starting gap recalculation for all shows..."

    total_shows = Show.published.count
    processed = 0

    pbar = ProgressBar.create(
      total: total_shows,
      format: "%a %B %c/%C %p%% %E"
    )

    # First pass: Populate previous performance gaps from Phish.net API
    puts "Phase 1: Fetching previous performance gaps from Phish.net API..."

    Show.published.order(:date).each do |show|
      begin
        GapService.call(show)
        processed += 1
        pbar.increment

        # Add a small delay to be respectful to the API
        sleep(0.1) if processed % 10 == 0
      rescue => e
        puts "\nError processing show #{show.date}: #{e.message}"
        pbar.increment
      end
    end

    pbar.finish

    # Second pass: Calculate next gaps and slugs based on local data
    puts "\nPhase 2: Calculating next gaps and slugs from local data..."

    processed = 0
    pbar = ProgressBar.create(
      total: total_shows,
      format: "%a %B %c/%C %p%% %E"
    )

    Show.published.order(:date).each do |show|
      begin
        GapSlugService.call(show)
        processed += 1
        pbar.increment
      rescue => e
        puts "\nError processing slugs for show #{show.date}: #{e.message}"
        pbar.increment
      end
    end

    pbar.finish

    puts "\n✅ Gap recalculation completed!"
    puts "Processed #{total_shows} shows"

    # Show some statistics
    total_gaps = SongsTrack.where.not(previous_performance_gap: nil).count
    puts "Total song performances with gap data: #{total_gaps}"
  end

  desc "Recalculate gaps for a specific show"
  task :recalculate_show, [:date] => :environment do |_task, args|
    date = args[:date]

    if date.blank?
      puts "Usage: rake gaps:recalculate_show[YYYY-MM-DD]"
      exit 1
    end

    show = Show.find_by(date: date)

    if show.nil?
      puts "Show not found for date: #{date}"
      exit 1
    end

    puts "Recalculating gaps for show: #{show.date} at #{show.venue.name}"

    # First get gaps from Phish.net
    GapService.call(show)
    puts "✅ Previous performance gaps updated from Phish.net"

    # Then calculate slugs and next gaps from local data
    GapSlugService.call(show)
    puts "✅ Slugs and next gaps updated from local data"

    # Show results
    gap_count = SongsTrack.joins(:track).where(tracks: { show: show }).where.not(previous_performance_gap: nil).count
    puts "Updated gap data for #{gap_count} song performances"
  end

  desc "Recalculate gaps for a date range"
  task :recalculate_range, [:start_date, :end_date] => :environment do |_task, args|
    start_date = args[:start_date]
    end_date = args[:end_date]

    if start_date.blank? || end_date.blank?
      puts "Usage: rake gaps:recalculate_range[YYYY-MM-DD,YYYY-MM-DD]"
      exit 1
    end

    shows = Show.published.where(date: start_date..end_date).order(:date)

    if shows.empty?
      puts "No shows found in date range: #{start_date} to #{end_date}"
      exit 1
    end

    puts "Recalculating gaps for #{shows.count} shows from #{start_date} to #{end_date}"

    pbar = ProgressBar.create(
      total: shows.count * 2, # Two phases
      format: "%a %B %c/%C %p%% %E"
    )

    # Phase 1: Previous gaps from Phish.net
    shows.each do |show|
      begin
        GapService.call(show)
        pbar.increment
        sleep(0.1) # Be respectful to the API
      rescue => e
        puts "\nError processing show #{show.date}: #{e.message}"
        pbar.increment
      end
    end

    # Phase 2: Next gaps and slugs from local data
    shows.each do |show|
      begin
        GapSlugService.call(show)
        pbar.increment
      rescue => e
        puts "\nError processing slugs for show #{show.date}: #{e.message}"
        pbar.increment
      end
    end

    pbar.finish
    puts "\n✅ Gap recalculation completed for date range!"
  end
end
