namespace :performance_gaps do
  desc "Reset and rebuild all performance gap data from scratch"
  task rebuild_all: :environment do
    puts "🔄 Starting complete rebuild of all performance gap data..."
    puts "This will reset all gap/slug data and rebuild from scratch."
    puts ""

    # Step 1: Reset all performance fields to nil
    puts "📊 Step 1: Resetting all performance gap and slug fields to nil..."
    total_songs_tracks = SongsTrack.count
    puts "Found #{total_songs_tracks} songs_tracks records to reset"

    SongsTrack.update_all(
      previous_performance_gap: nil,
      previous_performance_slug: nil,
      next_performance_gap: nil,
      next_performance_slug: nil
    )
    puts "✅ Reset all performance fields to nil"
    puts ""

    # Step 2: Run PerformanceGapService on all shows
    puts "📊 Step 2: Running PerformanceGapService on all shows..."
    total_shows = Show.published.count
    processed_gaps = 0

    pbar_gaps = ProgressBar.create(
      title: "Gap Service",
      total: total_shows,
      format: "%t: %a %B %c/%C %p%% %E"
    )

    Show.published.order(:date).each do |show|
      begin
        PerformanceGapService.call(show)
        processed_gaps += 1
        pbar_gaps.increment

        # Add a small delay to be respectful to the Phish.net API
        sleep(0.1) if processed_gaps % 10 == 0
      rescue => e
        puts "\nError processing gaps for show #{show.date}: #{e.message}"
        pbar_gaps.increment
      end
    end

    pbar_gaps.finish
    puts "✅ Completed PerformanceGapService for #{processed_gaps} shows"
    puts ""

    # Step 3: Run PerformanceSlugService on all shows
    puts "📊 Step 3: Running PerformanceSlugService on all shows..."
    processed_slugs = 0

    pbar_slugs = ProgressBar.create(
      title: "Slug Service",
      total: total_shows,
      format: "%t: %a %B %c/%C %p%% %E"
    )

    Show.published.order(:date).each do |show|
      begin
        PerformanceSlugService.call(show)
        processed_slugs += 1
        pbar_slugs.increment
      rescue => e
        puts "\nError processing slugs for show #{show.date}: #{e.message}"
        pbar_slugs.increment
      end
    end

    pbar_slugs.finish
    puts "✅ Completed PerformanceSlugService for #{processed_slugs} shows"
    puts ""

    # Step 4: Delete all bustout tags
    puts "📊 Step 4: Deleting all existing bustout tags..."
    bustout_tag = Tag.find_by(name: "Bustout")
    if bustout_tag
      bustout_count = TrackTag.where(tag: bustout_tag).count
      puts "Found #{bustout_count} existing bustout tags to delete"
      TrackTag.where(tag: bustout_tag).destroy_all
      puts "✅ Deleted all bustout tags"
    else
      puts "⚠️ No 'Bustout' tag found - skipping deletion"
    end
    puts ""

    # Step 5: Run BustoutTagService on all shows
    puts "📊 Step 5: Running BustoutTagService on all shows..."
    processed_bustouts = 0

    pbar_bustouts = ProgressBar.create(
      title: "Bustout Service",
      total: total_shows,
      format: "%t: %a %B %c/%C %p%% %E"
    )

    Show.published.order(:date).each do |show|
      begin
        BustoutTagService.call(show)
        processed_bustouts += 1
        pbar_bustouts.increment
      rescue => e
        puts "\nError processing bustouts for show #{show.date}: #{e.message}"
        pbar_bustouts.increment
      end
    end

    pbar_bustouts.finish
    puts "✅ Completed BustoutTagService for #{processed_bustouts} shows"
    puts ""

    # Final statistics
    puts "🎉 Complete rebuild finished!"
    puts "=" * 50
    puts "Final Statistics:"

    total_gaps = SongsTrack.where.not(previous_performance_gap: nil).count
    total_next_gaps = SongsTrack.where.not(next_performance_gap: nil).count
    total_prev_slugs = SongsTrack.where.not(previous_performance_slug: nil).count
    total_next_slugs = SongsTrack.where.not(next_performance_slug: nil).count
    total_bustout_tags = TrackTag.joins(:tag).where(tags: { name: "Bustout" }).count

    puts "• Total shows processed: #{total_shows}"
    puts "• Song performances with previous gap data: #{total_gaps}"
    puts "• Song performances with next gap data: #{total_next_gaps}"
    puts "• Song performances with previous slug data: #{total_prev_slugs}"
    puts "• Song performances with next slug data: #{total_next_slugs}"
    puts "• Total bustout tags created: #{total_bustout_tags}"
    puts ""
    puts "🚀 All performance gap data has been successfully rebuilt!"
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
        PerformanceGapService.call(show)
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
  task update_show: :environment do
    date = ENV["DATE"]

    if date.blank?
      puts "Usage: DATE=YYYY-MM-DD rake performance_gaps:update_show"
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
    PerformanceGapService.call(show)

    # Show results
    gap_count = SongsTrack.joins(:track).where(tracks: { show: show }).where.not(previous_performance_gap: nil).count
    puts "Updated gap data for #{gap_count} song performances"
  end
end
