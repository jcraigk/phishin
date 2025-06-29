namespace :performance_slugs do
  desc "Backfill performance slug data for all shows"
  task backfill: :environment do
    puts "Starting performance slug backfill for all shows..."

    total_shows = Show.published.count
    processed = 0

    pbar = ProgressBar.create(
      total: total_shows,
      format: "%a %B %c/%C %p%% %E"
    )

    puts "Calculating performance slugs for all shows..."

    Show.published.order(:date).each do |show|
      begin
        PerformanceSlugService.call(show)
        processed += 1
        pbar.increment
      rescue => e
        puts "\nError processing show #{show.date}: #{e.message}"
        pbar.increment
      end
    end

    pbar.finish

    puts "\n✅ Performance slug backfill completed!"
    puts "Processed #{total_shows} shows"

    # Show some statistics
    total_prev_slugs = SongsTrack.where.not(previous_performance_slug: nil).count
    total_next_slugs = SongsTrack.where.not(next_performance_slug: nil).count
    puts "Total song performances with previous performance slug: #{total_prev_slugs}"
    puts "Total song performances with next performance slug: #{total_next_slugs}"
  end

  desc "Update performance slugs for a specific show"
  task update_show: :environment do
    date = ENV["DATE"]

    if date.blank?
      puts "Usage: DATE=YYYY-MM-DD rake performance_slugs:update_show"
      exit 1
    end

    show = Show.find_by(date: date)

    if show.nil?
      puts "Show not found for date: #{date}"
      exit 1
    end

    puts "Updating performance slugs for show: #{show.date} at #{show.venue.name}"
    puts "--------"

    # Calculate slugs only
    PerformanceSlugService.call(show)

    # Show results
    slug_count = SongsTrack.joins(:track).where(tracks: { show: show }).where.not(previous_performance_slug: nil).count
    puts "Updated performance slug data for #{slug_count} song performances"
  end
end
