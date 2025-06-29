namespace :gaps do
  desc "Recalculate all gap data for all shows (alias for backfill)"
  task recalculate_all: :environment do
    Rake::Task["gaps:backfill"].invoke
  end

  desc "Backfill gap data by fetching setlists from Phish.net for all shows"
  task backfill: :environment do
    puts "Starting gap backfill for all shows..."

    total_shows = Show.published.count
    processed = 0

    pbar = ProgressBar.create(
      total: total_shows,
      format: "%a %B %c/%C %p%% %E"
    )

    puts "Fetching gap data from Phish.net API for all shows..."

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

    puts "\n✅ Gap backfill completed!"
    puts "Processed #{total_shows} shows"

    # Show some statistics
    total_gaps = SongsTrack.where.not(previous_performance_gap: nil).count
    total_next_gaps = SongsTrack.where.not(next_performance_gap: nil).count
    puts "Total song performances with previous gap data: #{total_gaps}"
    puts "Total song performances with next gap data: #{total_next_gaps}"
  end

  desc "Recalculate gaps for a specific show"
  task recalculate_show: :environment do
    date = ENV["DATE"]

    if date.blank?
      puts "Usage: DATE=YYYY-MM-DD rake gaps:recalculate_show"
      exit 1
    end

    show = Show.find_by(date: date)

    if show.nil?
      puts "Show not found for date: #{date}"
      exit 1
    end

    puts "Recalculating gaps for show: #{show.date} at #{show.venue.name}"
    puts "--------"

    # Get gaps from Phish.net (also updates next gaps on earlier shows)
    GapService.call(show)

    # Show results
    gap_count = SongsTrack.joins(:track).where(tracks: { show: show }).where.not(previous_performance_gap: nil).count
    puts "Updated gap data for #{gap_count} song performances"
  end


end
