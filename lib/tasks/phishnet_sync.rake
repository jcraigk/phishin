# rubocop:disable Rake/MethodDefinitionInTask
namespace :phishnet do
  # Venue duplication mappings - maps dupe venue name to keeper venue ID
  VENUE_DUPES = {
    "Post-Gazette Pavilion" => 635,
    "ALLTEL Pavilion" => 733,
    "The Agora Theatre" => 17,
    "Beta Theta Pi Frat House Party, Denison University" => 79,
    "Studio 8H, NBC Studios" => 465,
    "Gymnasium, University of Vermont" => 900,
    "1313 Club" => 2,
    "23 East Caberet" => 4,
    "86th Street Music Hall" => 959, # Vancouver with wrong state
    "Aragon Entertainment Center" => 961,
    "Atlantic Connection" => 930, # Oak Bluffs with encoding issue
    "Berkeley Square" => 77,
    "Broome County Arena" => 112,
    "Burlington Boat House" => 894,
    "Campus Pond, UMass Spring Concert, University of Massachusetts" => 888,
    "Commodore Ballroom" => 172, # Vancouver with different formatting
    "CoreStates Spectrum" => 729,
    "Dane County Exposition Center" => 197,
    "Galliard Auditorium" => 984,
    "Hersheypark Arena" => 314,
    "Ian McLean's Party, Connie Condon's Farm" => 329,
    "McCullough Social Hall, McCullough Student Center, Middlebury College" => 421,
    "Memorial Union Building, Granite State Room, University of New Hampshire" => 431,
    "Pacific Coliseum" => 771, # Vancouver with different formatting
    "Recreation Hall, University of California-Davis" => 562,
    "Sigma Phi Fraternity, Hamilton College" => 607,
    "Snivley Arena, University of New Hampshire" => 968,
    "Starwood Ampitheater" => 971,
    "The Agora Ballroom" => 17,
    "The Base Lodge, Stearns Hall, Johnson State College" => 68,
    "The Gathering Place, Norris University Center, Northwestern University" => 275,
    "The Ranch" => 852, # South Burlington vs Shelburne
    "Tree Cafe" => 689,
    "UCSB Events Center, University of California-Santa Barbara" => 694,
    "Valley Club Cafe" => 707,
    "Vogue Theatre" => 728, # Vancouver with different formatting
    "Wendell Recording Studio" => 743,
    "William Randolph Hearst Greek Theatre, University of California, Berkeley" => 750,
    "Worcester Memorial Auditorium" => 816, # Worcester vs Worcestor typo
    "Zepp" => 764,
    "Les Foufounes Ãlectriques" => 893,
    "Les Foufounes Ã\u0089lectriques" => 893,
    "Worcester Centrum Centre" => 757,
    "The Fox Theatre" => 788,
    "Harris-Millis Cafeteria - University of Vermont" => 306,
    "Summerstage at Sugarbush North" => 652,
    "Deer Creek Music Center" => 722,
    "GTE Virginia Beach Amphitheater" => 726,
    "The â\u0080\u009CEâ\u0080\u009D Center" => 225,
    "Meadows Music Theatre" => 425,
    "Blockbuster Desert Sky Pavilion" => 205,
    "FirstMerit Bank Pavilion at Northerly Island" => 768,
    "NBC Television Studios, Studio 6A" => 466,
    "NBC Television Studios, Studio 6B" => 466,
    "The Wharf Amphitheater" => 794
  }.freeze

  # Date-specific tour overrides - maps show date to tour name
  TOUR_DATE_OVERRIDES = {
    "2025-01-28" => "Mexico Run 2025"
  }.freeze

  # Dates to skip during sync (manually managed)
  MANUALLY_MANAGED_DATES = [
    "1988-02-20",
    "1990-04-19",
    "2000-05-19"
  ].freeze

  desc "Sync all known Phish show dates from Phish.net (use LIMIT env var to limit new shows, DATE env var for single date)"
  task sync_shows: :environment do
    date_filter = ENV["DATE"]
    limit = ENV["LIMIT"]&.to_i

    # Only run setup operations if not syncing a specific date
    unless date_filter
      # Reset tracking at the beginning
      reset_skipped_shows
      reset_additional_local_tracks

      # Set specific shows to missing audio status before sync
      shows_to_mark_missing = [ "1985-02-25", "1985-05-01" ]
      shows_to_mark_missing.each do |date|
        show = Show.find_by(date:)
        if show
          show.update!(audio_status: "missing")
          puts "Set https://phish.in/#{date} to missing audio status"
        else
          puts "Show not found: #{date}"
        end
      end

      # Set specific show to partial audio status before sync
      show_2000_05_19 = Show.find_by(date: "2000-05-19")
      if show_2000_05_19
        show_2000_05_19.update!(audio_status: "partial")
        puts "Set https://phish.in/2000-05-19 to partial audio status"
      else
        puts "Show not found: 2000-05-19"
      end

      # Set specific tracks to missing audio status before sync
      tracks_to_mark_missing = [
        "https://phish.in/2000-05-19/funky-bitch",
        "https://phish.in/2000-05-19/my-soul"
      ]

      tracks_to_mark_missing.each do |url|
        track = Track.by_url(url)
        if track
          track.update!(audio_status: "missing")
          puts "Set #{url} to missing audio status"
        else
          puts "Track not found: #{url}"
        end
      end

      # Set all tracks with CUT tag to partial audio status
      cut_tag = Tag.find_by(name: "CUT")
      cut_tracks = Track.joins(:tags).where(tags: { id: cut_tag.id })
      cut_tracks.each do |track|
        if track.audio_status != "partial"
          track.update!(audio_status: "partial")
          puts "Set #{track.url} to partial audio status (has CUT tag)"
        end
      end
      puts "Processed #{cut_tracks.count} tracks with CUT tag"
    end

    if date_filter
      puts "Starting Phish.net sync for specific date: #{date_filter}..."

      # Get specific date from Phish.net
      response = Typhoeus.get(
        "https://api.phish.net/v5/shows/showdate/#{date_filter}.json",
        params: { apikey: ENV.fetch("PNET_API_KEY", nil) }
      )

      if response.success?
        data = JSON.parse(response.body)
        if data["data"] && data["data"].any?
          pnet_show = data["data"].first
          puts "Found show for #{date_filter} on Phish.net"

          begin
            process_phishnet_show(pnet_show, [ pnet_show ])
            puts "Sync complete for #{date_filter}!"
          rescue StandardError => e
            puts "Error processing show #{date_filter}: #{e.message}"
            raise e
          end

        # Report any skipped shows and additional local tracks
        report_skipped_shows
        report_additional_local_tracks
        else
          puts "No show found for #{date_filter} on Phish.net"
        end
      else
        puts "Error fetching data from Phish.net: #{response.code}"
      end
    else
      puts "Starting Phish.net sync#{limit && limit > 0 ? " (limited to #{limit} new shows)" : ''}..."

      # Get all known dates from Phish.net (artist-specific endpoint)
      response = Typhoeus.get(
        "https://api.phish.net/v5/shows/artist/phish.json",
        params: {
          apikey: ENV.fetch("PNET_API_KEY", nil),
          order_by: "showdate"
        }
      )

      if response.success?
        data = JSON.parse(response.body)
        shows_data = data["data"]

        puts "Found #{shows_data.length} shows on Phish.net"

        # Filter to only shows we don't have locally if limit is specified
        if limit && limit > 0
          new_shows_data = shows_data.select do |pnet_show|
            date = Date.parse(pnet_show["showdate"])
            !Show.exists?(date:)
          end

          puts "Found #{new_shows_data.length} shows not in local database"

          if new_shows_data.length > limit
            new_shows_data = new_shows_data.first(limit)
            puts "Limiting to first #{limit} new shows"
          end

          shows_to_process = new_shows_data
        else
          shows_to_process = shows_data
        end

        # Create progress bar
        progressbar = ProgressBar.create(
          title: "Syncing",
          total: shows_to_process.length,
          format: "%a |%b>>%i| %p%% %t"
        )

        shows_to_process.each_with_index do |pnet_show, index|
          begin
            process_phishnet_show(pnet_show, shows_data)
          rescue StandardError => e
            puts "\nError processing show #{pnet_show['showdate']}: #{e.message}"
            raise e # Re-raise to stop the process
          end
          progressbar.increment
        end

        puts "\nSync complete!"

        # Report any skipped shows and additional local tracks
        report_skipped_shows
        report_additional_local_tracks
      else
        puts "Error fetching data from Phish.net: #{response.code}"
      end
    end
  end

  private

  # Module variables to track shows skipped due to duplicate positions/sets and additional local tracks
  @skipped_shows_with_duplicates = []
  @additional_local_tracks = []

  def reset_skipped_shows
    @skipped_shows_with_duplicates = []
  end

  def reset_additional_local_tracks
    @additional_local_tracks = []
  end

  def add_skipped_show(show_date, reason)
    @skipped_shows_with_duplicates << { date: show_date, reason: }
  end

  def add_additional_local_track(track)
    # Filter out excluded track titles and song titles
    excluded_titles = %w[intro outro jam banter interview]

    # Check track title
    normalized_track_title = track.title.downcase.strip
    return if excluded_titles.include?(normalized_track_title)

    # Check if any of the track's songs have excluded titles
    track.songs.each do |song|
      normalized_song_title = song.title.downcase.strip
      return if excluded_titles.include?(normalized_song_title)
    end

    # Filter out soundcheck tracks (set "S")
    return if track.set == "S"

    @additional_local_tracks << track.url
  end

  def report_skipped_shows
    return if @skipped_shows_with_duplicates.empty?

    puts "\n" + "=" * 80
    puts "⚠️  SHOWS SKIPPED DUE TO DUPLICATE POSITIONS/SETS:"
    puts "=" * 80
    @skipped_shows_with_duplicates.each do |skipped|
      puts "#{skipped[:date]} - #{skipped[:reason]}"
    end
    puts "\nThese shows need manual review. The PhishNet maintainer suggests"
    puts "using show ID instead of date for shows with multiple performances."
    puts "=" * 80
  end

  def report_additional_local_tracks
    return if @additional_local_tracks.empty?

    puts "\n" + "=" * 80
    puts "📋 ADDITIONAL LOCAL TRACKS NOT IN PHISHNET:"
    puts "=" * 80
    puts "Found #{@additional_local_tracks.length} additional local tracks"
    puts "=" * 80

    @additional_local_tracks.sort.uniq.each do |url|
      puts url
    end
    puts "=" * 80
  end

  # Helper method to fetch and filter setlist data for a specific show
  def fetch_setlist_data_for_show(show_date, show_id)
    response = Typhoeus.get(
      "https://api.phish.net/v5/setlists/showdate/#{show_date.strftime('%Y-%m-%d')}.json",
      params: { apikey: ENV.fetch("PNET_API_KEY", nil) }
    )

    return [] unless response.success?

    data = JSON.parse(response.body)
    return [] unless data["data"] && data["data"].any?

    # Filter to only include Phish tracks for the specific show
    data["data"].select do |song_data|
      song_data["artist_slug"] == "phish" &&
      song_data["showid"].to_s == show_id.to_s
    end
  rescue JSON::ParserError
    []
  end

  # Helper method to detect duplicate positions/sets in PhishNet setlist data
  def has_duplicate_positions_or_sets?(setlist_data)
    return false unless setlist_data && setlist_data.any?

    # Check for duplicate positions
    position_counts = Hash.new(0)
    setlist_data.each { |song_data| position_counts[song_data["position"]] += 1 }
    duplicate_positions = position_counts.select { |pos, count| count > 1 }

    # Check for duplicate position/set combinations
    position_set_counts = Hash.new(0)
    setlist_data.each do |song_data|
      key = "#{song_data['position']}-#{song_data['set']}"
      position_set_counts[key] += 1
    end
    duplicate_position_sets = position_set_counts.select { |key, count| count > 1 }

    if duplicate_positions.any? || duplicate_position_sets.any?
      duplicate_info = []
      duplicate_info << "positions: #{duplicate_positions.keys.join(', ')}" if duplicate_positions.any?
      duplicate_info << "position/set combos: #{duplicate_position_sets.keys.join(', ')}" if duplicate_position_sets.any?
      return duplicate_info.join("; ")
    end

    false
  end

  def process_phishnet_show(pnet_show, all_shows_data = nil)
    date = Date.parse(pnet_show["showdate"])

    # Skip future shows (including today, since shows haven't happened yet)
    if date >= Date.current
      # puts "Skipping future show: #{pnet_show['showdate']}"
      return
    end

    # Skip canceled shows (check setlist_notes for cancellation)
    setlist_notes = pnet_show["setlist_notes"] || ""
    if setlist_notes.include?("performance was canceled")
      return
    end

    # Skip specific rained out shows
    rained_out_shows = [ "1996-07-02" ]
    if rained_out_shows.include?(pnet_show["showdate"])
      # puts "Skipping rained out show: #{pnet_show['showdate']}"
      return
    end

    # Skip manually managed dates
    if MANUALLY_MANAGED_DATES.include?(pnet_show["showdate"])
      # puts "Skipping manually managed show: #{pnet_show['showdate']}"
      return
    end

    # Handle exclude_from_stats field from Phish.net API
    exclude_from_stats = pnet_show["exclude_from_stats"] == 1


    show = Show.find_or_initialize_by(date:)

    # Handle exclude_from_stats logic:
    # - If exclude_from_stats is true and there's only one show on this date in remote data,
    #   update the existing local show to mark it as excluded
    # - If exclude_from_stats is true and there are multiple shows on this date, skip processing
    if exclude_from_stats
      # Check if there are multiple shows on this date in the remote data
      if all_shows_data
        shows_on_date = all_shows_data.select { |s| s["showdate"] == pnet_show["showdate"] }
        if shows_on_date.length > 1
          # puts "Skipping show excluded from stats (multiple shows on date): #{pnet_show['showdate']}"
          return
        end
      end

      # Only one show on this date - update existing local show to mark as excluded
      if show.persisted?
        show.performance_gap_value = 0
        show.save!
        # puts "Updated existing show to exclude from stats: #{pnet_show['showdate']}"
      end
      return
    end

    # Find or create venue
    venue = find_or_create_venue(pnet_show)

    # Update show attributes
    show.venue = venue if venue
    show.venue_name = pnet_show["venue"] || "Unknown Venue"

    # Find existing tour - tour is required for all shows
    # Check for date-specific overrides first
    if TOUR_DATE_OVERRIDES.key?(pnet_show["showdate"])
      override_tour_name = TOUR_DATE_OVERRIDES[pnet_show["showdate"]]
      tour = Tour.find_by(name: override_tour_name)
      unless tour
        puts "\nMissing override tour: #{override_tour_name} for show #{pnet_show['showdate']}"
        puts "Please create this tour manually and re-run the sync."
        exit 1
      end
      puts "Using tour override: #{override_tour_name} for show #{pnet_show['showdate']}"
    else
      tour_name = pnet_show["tourname"] || pnet_show["tour_name"] || "Not Part of a Tour"
      tour = find_tour_by_name(tour_name)
      unless tour
        puts "\nMissing tour: #{tour_name} for show #{pnet_show['showdate']}"
        puts "Please create this tour manually and re-run the sync."
        exit 1
      end
    end
    show.tour = tour

    # Note: All shows are now considered published by default

    # Set performance_gap_value to 0 for shows excluded from stats
    if exclude_from_stats
      show.performance_gap_value = 0
    end

    # If show is new and has no tracks, it's missing audio
    if show.new_record?
      show.audio_status = "missing"
      # Note: incomplete field is computed from audio_status, no need to set it
    end

    show.save!

    # Extract showid from pnet_show for filtering setlist data
    show_id = pnet_show["showid"]

    # Check for duplicate positions/sets in PhishNet data before processing setlists
    if show.audio_status == "missing" || show.audio_status == "partial"
      # Fetch setlist data to check for duplicates
      setlist_data = fetch_setlist_data_for_show(show.date, show_id)
      if setlist_data.any?
        duplicate_info = has_duplicate_positions_or_sets?(setlist_data)
        if duplicate_info
          puts "⚠️  Skipping show #{show.date} due to duplicate #{duplicate_info}"
          add_skipped_show(show.date.to_s, "Duplicate #{duplicate_info}")
          return
        end
      end
    end

    # Handle setlist synchronization based on audio status
    if show.audio_status == "missing"
      # Handle missing audio shows (destroy and replace)
      if show.tracks.any?
        if setlist_differs_from_local?(show, show_id)
          show.tracks.destroy_all
          fetch_and_process_setlist(show, show_id)
        end
      else
        fetch_and_process_setlist(show, show_id)
      end
    elsif show.audio_status == "partial"
      # Handle partial audio shows (merge with existing)
      if setlist_differs_from_local?(show, show_id)
        merge_partial_setlist(show, show_id)
      end
    elsif show.audio_status == "complete"
      # Skip setlist processing for complete audio shows
      # puts "Show #{show.date} has complete audio - skipping setlist processing"
    end
  end

  def find_or_create_venue(pnet_show)
    return nil unless pnet_show["venue"].present?

    # Store original values before UTF-8 fixing
    original_venue_name = pnet_show["venue"].strip
    original_city = (pnet_show["city"] || "Unknown").strip

    # Apply UTF-8 fixes
    venue_name = fix_utf8_encoding(original_venue_name)
    city = fix_utf8_encoding(original_city)
    state = pnet_show["state"] || pnet_show["country"] || "Unknown"
    country = pnet_show["country"] || "USA"

    # If this venue matches a known duplicate, use the keeper instead
    if VENUE_DUPES.key?(venue_name)
      keeper_id = VENUE_DUPES[venue_name]
      keeper_venue = Venue.find_by(id: keeper_id)
      if keeper_venue
        puts "Substituting venue ##{keeper_id} for #{venue_name}"
        return keeper_venue
      end
    end

    # Also check with original (pre-UTF8-fix) values
    if VENUE_DUPES.key?(original_venue_name)
      keeper_id = VENUE_DUPES[original_venue_name]
      keeper_venue = Venue.find_by(id: keeper_id)
      if keeper_venue
        puts "Using keeper venue: #{keeper_venue.name} (ID: #{keeper_id}) instead of potential dupe: #{original_venue_name}"
        return keeper_venue
      end
    end

    # Special venue and city mappings for cases where both name and city differ
    # Check both original (broken UTF-8) and fixed versions
    venue_city_mappings = {
      [ "Summerstage at Sugarbush North", "Fayston" ] => [ "Summer Stage at Sugarbush", "North Fayston" ],
      [ "The Orpheum Theatre", "Vancouver, British Columbia" ] => [ "The Orpheum", "Vancouver" ],
      [ "Hurricane Festival", "ScheeÃ\u009Fel" ] => [ "Hurricane Festival", "Scheeßel" ],
      [ "GM Place", "Vancouver, British Columbia" ] => [ "GM Place", "Vancouver" ],
      [ "Austin360 Amphitheater", "Del Valle" ] => [ "Austin360 Amphitheater", "Austin" ]
    }

    # Check for venue and city mapping first - use original (broken UTF-8) values for mapping
    venue_city_key = [ original_venue_name, original_city ]
    if venue_city_mappings.key?(venue_city_key)
      mapped_venue_name, mapped_city = venue_city_mappings[venue_city_key]
      venue = Venue.where("lower(name) = ? AND lower(city) = ?", mapped_venue_name.downcase, mapped_city.downcase).first
      return venue if venue
    end

    # Special case for "Unknown Venue" - match only on name, ignore city
    if venue_name == "Unknown Venue"
      venue = Venue.left_outer_joins(:venue_renames)
                   .where("venues.name = :name OR venue_renames.name = :name", name: venue_name)
                   .first
      return venue if venue
    end

    # Try to find existing venue, checking both current name and venue renames
    # For non-USA venues, ignore city and state/province differences and match on venue name and country only
    if country != "USA"
      venue = Venue.left_outer_joins(:venue_renames)
                   .where(
                     "(venues.name = :name OR venue_renames.name = :name) AND venues.country = :country",
                     name: venue_name,
                     country:
                   ).first
      return venue if venue
    else
      venue = Venue.left_outer_joins(:venue_renames)
                   .where(
                     "(venues.name = :name OR venue_renames.name = :name) AND lower(venues.city) = :city",
                     name: venue_name,
                     city: city.downcase
                   ).first
      return venue if venue
    end

    # Venue not found - provide Rails console command and halt
    show_date = pnet_show["showdate"]
    puts "\nMissing venue for show #{show_date}: #{venue_name}"
    puts "Please create this venue manually using the Rails console:"
    puts "Venue.create!(name: \"#{venue_name}\", city: \"#{city}\", state: \"#{state}\", country: \"#{country}\", slug: \"#{venue_name.parameterize}\")"
    print "Enter the ID of the venue you just created: "
    venue_id = STDIN.gets.strip.to_i

    venue = Venue.find_by(id: venue_id)
    unless venue
      puts "Venue with ID #{venue_id} not found. Exiting."
      exit 1
    end

    puts "Using venue: #{venue.name} (ID: #{venue.id})"
    venue
  end

  # New method to handle partial audio shows intelligently
  def merge_partial_setlist(show, show_id)
    # Fetch filtered setlist data for this specific show
    phish_tracks = fetch_setlist_data_for_show(show.date, show_id)

    unless phish_tracks.any?
      puts "No setlist data available for #{show.date}"
      return
    end

    puts "Merging partial setlist for #{show.date} (#{phish_tracks.length} tracks from PhishNet)"

    # Get existing tracks
    existing_tracks = show.tracks.includes(:songs).order(:position)

    # Create a map of existing tracks by song title and set for easy lookup
    # Each song within a track gets its own key pointing to the same track
    existing_track_map = {}
    existing_tracks.each do |track|
      track.songs.each do |song|
        key = build_track_key(song.title, track.set)
        existing_track_map[key] = track
      end
    end

    # Also create a map by slug to handle slug conflicts
    existing_slug_map = {}
    existing_tracks.each do |track|
      existing_slug_map[track.slug] = track
    end



    tracks_created = 0
    tracks_repositioned = 0

    ActiveRecord::Base.transaction do
      # First, move all existing tracks to temporary positions to avoid conflicts
      # Use a high temporary position that won't conflict with existing tracks
      max_position = show.tracks.maximum(:position) || 0
      temp_position_start = [ max_position + 1000, 10000 ].max
      existing_tracks.each_with_index do |track, index|
        track.update_column(:position, temp_position_start + index)
      end

      # Process tracks in position order to handle insertions properly
      phish_tracks_sorted = phish_tracks.sort_by { |song_data| song_data["position"] || 0 }

      phish_tracks_sorted.each_with_index do |song_data, index|
        # Apply title mappings before song lookup
        original_title = (song_data["song"] || "").strip
        mapped_title = apply_title_mapping(original_title)

        # Update song_data with mapped title for song lookup
        song_data_with_mapping = song_data.dup
        song_data_with_mapping["song"] = mapped_title

        song = find_or_create_song(song_data_with_mapping, show)
        next unless song

        pnet_title = mapped_title
        pnet_set = song_data["set"] || "1"
        pnet_position = song_data["position"] || (index + 1)

        track_key = build_track_key(pnet_title, pnet_set)

        # Check if track exists by title/set combination
        existing_track = existing_track_map[track_key]

        # If not found by title/set, check if there's a slug conflict
        if !existing_track
          # Generate what the slug would be for this track
          temp_track = Track.new(title: pnet_title, show:)
          temp_track.generate_slug
          potential_slug = temp_track.slug

          # Check if this slug already exists
          if existing_slug_map[potential_slug]
            existing_track = existing_slug_map[potential_slug]
          end
        end

        if existing_track
          # Track exists - move it to the correct position
          existing_track.update!(position: pnet_position)
          tracks_repositioned += 1
        else
          # Track doesn't exist - create it
          track = show.tracks.build(
            title: pnet_title,
            position: pnet_position,
            set: pnet_set,
            audio_status: "missing"
          )

          # Add song association
          track.songs << song
          track.save!
          tracks_created += 1

          # Update our existing_track_map to include the new track
          existing_track_map[track_key] = track
          existing_slug_map[track.slug] = track
        end
      end

      # Ensure tight sequential ordering of all tracks (1, 2, 3, 4, etc.)
      final_tracks = show.tracks.reload.order(:position)
      final_tracks.each_with_index do |track, index|
        new_position = index + 1
        if track.position != new_position
          track.update_column(:position, new_position)
        end
      end

      # Remove any existing tracks that are no longer in the PhishNet setlist
      # This handles cases where our local data had incorrect tracks
      pnet_track_keys = phish_tracks.map do |song_data|
        original_title = (song_data["song"] || song_data["title"] || "").strip
        mapped_title = apply_title_mapping(original_title)
        pnet_set = song_data["set"] || "1"
        build_track_key(mapped_title, pnet_set)
      end.compact

      tracks_to_remove = existing_tracks.reject do |track|
        # A track should be kept if ANY of its songs are in the PhishNet setlist
        track.songs.any? do |song|
          song_key = build_track_key(song.title, track.set)
          pnet_track_keys.include?(song_key)
        end
      end

      tracks_removed = 0
      tracks_to_remove.each do |track|
        # Track additional local tracks (all tracks that don't match PhishNet)
        add_additional_local_track(track)

        # Only remove tracks that have missing audio - preserve tracks with audio
        if track.audio_status == "missing"
          track.destroy!
          tracks_removed += 1
        end
      end

      puts "Created #{tracks_created} tracks, repositioned #{tracks_repositioned} tracks, removed #{tracks_removed} tracks for #{show.date}"
    end

    # Update show's audio status based on final track composition
    show.update_audio_status_from_tracks!
  end



  # Helper method to apply title mappings
  def apply_title_mapping(title)
    normalized_title = title.to_s.strip.downcase

    # Hardcoded mappings for PhishNet titles that should match local titles
    title_mappings = {
      "digital delay loop jam" => "Jam",
      "let's go" => "Let's Go (The Cars)"
    }

    title_mappings[normalized_title] || title
  end

  # Helper method to create consistent track keys for comparison
  def build_track_key(title, set)
    # Normalize title and set for comparison
    normalized_title = title.to_s.strip.downcase
    normalized_set = set.to_s.strip.upcase  # Normalize set to uppercase
    "#{normalized_title}|#{normalized_set}"
  end

  def find_tour_by_name(tour_name)
    # First try exact match
    tour = Tour.find_by(name: tour_name)
    return tour if tour

    # Hardcoded mappings for specific tour names
    hardcoded_mappings = {
      "1997 Fall Tour (a.k.a. Phish Destroys America)" => "Fall Tour 1997",
      "2003 20th Anniversary Run" => "20th Anniversary Run",
      "2022 Madison Square Garden Spring Run" => "MSG Spring Run 2022",
      "2025 Late Summer Tour" => "Summer Tour 2025"
    }

    if hardcoded_mappings.key?(tour_name)
      alternative_name = hardcoded_mappings[tour_name]
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # puts "Trying to match tour: '#{tour_name}'"

    # Handle NYE Run patterns: various formats -> "New Years Run YYYY"
    # Matches: "YYYY NYE Run", "YYYY NYE", "YYYY/YYYY+1 NYE Run", "YYYY/YYYY+1 Inverted NYE Run"
    if match = tour_name.match(/^(\d{4})(?:\/\d{4})?\s+(?:Inverted\s+)?NYE(?:\s+Run)?$/i)
      year = match[1]
      alternative_name = "New Years Run #{year}"
      # puts "Trying NYE pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # Handle "YYYY/YYYY+1 New Year's Run" pattern
    if match = tour_name.match(/^(\d{4})(?:\/\d{4})?\s+New\s+Year'?s?\s+Run$/i)
      year = match[1]
      alternative_name = "New Years Run #{year}"
      # puts "Trying New Year's Run pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # Also try with "New Year's" (with apostrophe)
    if match = tour_name.match(/^(\d{4})(?:\/\d{4})?\s+(?:Inverted\s+)?NYE(?:\s+Run)?$/i)
      year = match[1]
      alternative_name = "New Year's Run #{year}"
      # puts "Trying NYE pattern with apostrophe: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    if match = tour_name.match(/^New\s+Years\s+Run\s+(\d{4})$/i)
      year = match[1]
      alternative_name = "#{year} NYE Run"
      # puts "Trying reverse NYE pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # Handle season patterns: "YYYY Season" -> "Season Tour YYYY"
    if match = tour_name.match(/^(\d{4})\s+(Spring|Summer|Fall|Winter)$/i)
      year = match[1]
      season = match[2]
      alternative_name = "#{season} Tour #{year}"
      # puts "Trying season pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # Handle location patterns: "YYYY Location" -> "Location Run YYYY"
    # Common locations: Mexico, Japan, Europe, etc.
    if match = tour_name.match(/^(\d{4})\s+(Mexico|Japan|Europe|Asia|Australia|UK|Caribbean)$/i)
      year = match[1]
      location = match[2]
      alternative_name = "#{location} Run #{year}"
      # puts "Trying location pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # If tour name matches pattern "YYYY Tour Name", try "Tour Name YYYY" format
    if tour_name.match?(/^\d{4}\s+(.+)/)
      year = tour_name[0..3]
      rest_of_name = tour_name[5..-1]
      alternative_name = "#{rest_of_name} #{year}"
      # puts "Trying year-first pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # If tour name matches pattern "Tour Name YYYY", try "YYYY Tour Name" format
    if tour_name.match?(/^(.+)\s+\d{4}$/)
      parts = tour_name.split
      year = parts.last
      rest_of_name = parts[0..-2].join(" ")
      alternative_name = "#{year} #{rest_of_name}"
      # puts "Trying year-last pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    puts "No match found for: '#{tour_name}'"
    nil
  end

  def fetch_and_process_setlist(show, show_id)
    # Fetch filtered setlist data for this specific show
    phish_tracks = fetch_setlist_data_for_show(show.date, show_id)

    if phish_tracks.any?
      # puts "Processing setlist for #{show.date} (#{phish_tracks.length} tracks)"
      process_setlist(show, phish_tracks)
    else
      # puts "No setlist data available for #{show.date}"
    end
  end

  def process_setlist(show, phish_tracks)
    tracks_created = 0

    # phish_tracks is already filtered to only include Phish tracks for the specific show
    phish_tracks.each_with_index do |song_data, index|
      song = find_or_create_song(song_data, show)
      next unless song

      # Get set code from the song data
      set_code = song_data["set"] || "1"

      # Create track with missing audio and song association in transaction
      track = nil
      ActiveRecord::Base.transaction do
        track = show.tracks.build(
          title: (song_data["song"] || song.title).strip,
          position: song_data["position"] || (index + 1),
          set: set_code,
          audio_status: "missing"
        )

        # Add song association before saving to satisfy validation
        track.songs << song
        track.save!
      end

      tracks_created += 1
    end

    puts "Created #{tracks_created} tracks for #{show.date}"
  end

  def find_or_create_song(song_data, show)
    song_title = fix_utf8_encoding(song_data["song"]).strip
    return nil unless song_title.present?

    # Hardcoded song mappings
    song_mappings = {
      "Unknown Song" => "Unknown"
    }

    # Check if we have a hardcoded mapping
    if song_mappings.key?(song_title)
      mapped_song_title = song_mappings[song_title]
      song = Song.where("lower(title) = ?", mapped_song_title.downcase).first
      return song if song
    end

    # Try to find existing song (case insensitive)
    song = Song.where("lower(title) = ?", song_title.downcase).first
    return song if song

    # Song not found - provide Rails console command and halt
    puts "\nMissing song for show #{show.date}: #{song_title}"
    puts "Please create this song manually using the Rails console:"
    puts "Song.create!(title: #{song_title.inspect})"
    print "Enter the ID of the song you just created: "
    song_id = STDIN.gets.strip.to_i

    song = Song.find_by(id: song_id)
    unless song
      puts "Song with ID #{song_id} not found. Exiting."
      exit 1
    end

    puts "Using song: #{song.title} (ID: #{song.id})"
    song
  end

  def fix_utf8_encoding(text)
    return text unless text.is_a?(String)

    # Common UTF-8 encoding fixes
    utf8_fixes = {
      "Ã¡" => "á",  # á
      "Ã©" => "é",  # é
      "Ã­" => "í",  # í
      "Ã³" => "ó",  # ó
      "Ãº" => "ú",  # ú
      "Ã±" => "ñ",  # ñ
      "Ã¼" => "ü",  # ü
      "Ã¤" => "ä",  # ä
      "Ã¶" => "ö",  # ö
      "Ã " => "à",  # à
      "Ã¨" => "è",  # è
      "Ã¬" => "ì",  # ì
      "Ã²" => "ò",  # ò
      "Ã¹" => "ù",  # ù
      "Ã¢" => "â",  # â
      "Ãª" => "ê",  # ê
      "Ã®" => "î",  # î
      "Ã´" => "ô",  # ô
      "Ã»" => "û",  # û
      "Ã‡" => "Ç",  # Ç
      "Ã†" => "Æ",  # Æ
      "Ã˜" => "Ø",  # Ø
      "Ã…" => "Å",  # Å
      "ÃŸ" => "ß",  # ß
      "Ãe" => "ße",  # ße (for ScheeÃel -> Scheeßel)
      "Ã\u0089" => "É",  # É (Unicode escape sequence)
      "â\u0080\u0099" => "'"  # Right single quote (mangled UTF-8)
    }

    fixed_text = text.dup
    utf8_fixes.each do |broken, correct|
      fixed_text.gsub!(broken, correct)
    end

    fixed_text
  end

  def setlist_differs_from_local?(show, show_id)
    # Fetch filtered setlist data for this specific show
    remote_setlist = fetch_setlist_data_for_show(show.date, show_id)
    local_tracks = show.tracks.includes(:songs).order(:position)

    # For partial audio shows, we need to be more lenient in comparison
    # because we might have fewer tracks locally than PhishNet
    if show.audio_status == "partial"
      return partial_setlist_differs?(remote_setlist, local_tracks)
    end

    # For missing audio shows, use the existing logic
    return false if remote_setlist.length != local_tracks.length

    # Compare each track
    remote_setlist.each_with_index do |song_data, index|
      local_track = local_tracks[index]

      # Compare track title (case insensitive, with whitespace trimmed)
      # Apply title mappings consistently with merge_partial_setlist
      original_title = (song_data["song"] || "").strip
      mapped_title = apply_title_mapping(original_title)
      remote_title = mapped_title.downcase.strip
      local_track_title = local_track.title&.downcase&.strip

      return true if remote_title != local_track_title

      # Compare set
      remote_set = song_data["set"] || "1"
      return true if remote_set != local_track.set

      # Compare position - ensure consistent logic with track creation
      # In process_setlist, we use song_data["position"] || (index + 1), so do the same here
      remote_position = song_data["position"] || (index + 1)
      return true if remote_position != local_track.position
    end

    false
  end

  # New method to determine if partial setlist differs
  def partial_setlist_differs?(remote_setlist, local_tracks)
    # Create maps for easier comparison
    remote_track_map = {}
    remote_setlist.each_with_index do |song_data, index|
      # Apply title mappings consistently with merge_partial_setlist
      original_title = (song_data["song"] || "").strip
      mapped_title = apply_title_mapping(original_title)
      title = mapped_title.downcase.strip
      set = song_data["set"] || "1"
      position = song_data["position"] || (index + 1)
      key = build_track_key(title, set)
      remote_track_map[key] = { title:, set:, position: }
    end

    local_track_map = {}
    local_tracks.each do |track|
      track.songs.each do |song|
        key = build_track_key(song.title, track.set)
        local_track_map[key] = { title: song.title.downcase.strip, set: track.set, position: track.position }
      end
    end

    # Check if we're missing tracks from PhishNet
    missing_tracks = remote_track_map.keys - local_track_map.keys
    return true if missing_tracks.any?

    # Track additional local tracks that exist but aren't in PhishNet
    additional_local_keys = local_track_map.keys - remote_track_map.keys
    if additional_local_keys.any?
      # Find the actual track objects for these additional tracks
      additional_local_keys.each do |key|
        # Find the track that matches this key
        local_tracks.each do |track|
          track.songs.each do |song|
            track_key = build_track_key(song.title, track.set)
            if track_key == key
              add_additional_local_track(track)
              break
            end
          end
        end
      end
    end

    # Check if existing tracks have different positions
    local_track_map.each do |key, local_data|
      if remote_track_map[key]
        remote_data = remote_track_map[key]
        return true if local_data[:position] != remote_data[:position]
      end
    end

    false
  end
end
# rubocop:enable Rake/MethodDefinitionInTask
