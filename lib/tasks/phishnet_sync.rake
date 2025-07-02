# rubocop:disable Rake/MethodDefinitionInTask
namespace :phishnet do
    desc "Sync all known Phish show dates from Phish.net (use LIMIT env var to limit new shows, DATE env var for single date)"
  task sync_shows: :environment do
    date_filter = ENV['DATE']
    limit = ENV['LIMIT']&.to_i

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
            process_phishnet_show(pnet_show)
            puts "Sync complete for #{date_filter}!"
          rescue StandardError => e
            puts "Error processing show #{date_filter}: #{e.message}"
            raise e
          end
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
            !Show.exists?(date: date)
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
            process_phishnet_show(pnet_show)
          rescue StandardError => e
            puts "\nError processing show #{pnet_show['showdate']}: #{e.message}"
            raise e # Re-raise to stop the process
          end
          progressbar.increment
        end

        puts "\nSync complete!"
      else
        puts "Error fetching data from Phish.net: #{response.code}"
      end
    end
  end

  desc "Sync a specific date range from Phish.net"
  task :sync_date_range, [ :start_date, :end_date ] => :environment do |t, args|
    start_date = Date.parse(args[:start_date])
    end_date = Date.parse(args[:end_date])
    date_range = (start_date..end_date).to_a

    puts "Syncing shows from #{start_date} to #{end_date}..."

    # Create progress bar for date range
    progressbar = ProgressBar.create(
      title: "Syncing",
      total: date_range.length,
      format: "%a |%b>>%i| %p%% %t"
    )

    date_range.each do |date|
      response = Typhoeus.get(
        "https://api.phish.net/v5/shows/showdate/#{date.strftime('%Y-%m-%d')}.json",
        params: { apikey: Rails.application.credentials.dig(:phishnet, :api_key) }
      )

      if response.success?
        data = JSON.parse(response.body)
        if data["data"] && data["data"].any?
          process_phishnet_show(data["data"].first)
        end
      end
      progressbar.increment
    end

    puts "\nSync complete!"
  end

  private

  def process_phishnet_show(pnet_show)
    date = Date.parse(pnet_show["showdate"])

    # Skip future shows
    if date > Date.current
      # puts "  Skipping future show: #{pnet_show['showdate']}"
      return
    end

    # Skip canceled tours
    tour_name = pnet_show["tourname"] || pnet_show["tour_name"] || ""
    canceled_tours = ["2020 Summer Tour"]
    if canceled_tours.include?(tour_name)
      # puts "  Skipping show from canceled tour: #{pnet_show['showdate']} (#{tour_name})"
      return
    end

    # Skip specific rained out shows
    rained_out_shows = ["1996-07-02"]
    if rained_out_shows.include?(pnet_show["showdate"])
      # puts "  Skipping rained out show: #{pnet_show['showdate']}"
      return
    end

    show = Show.find_or_initialize_by(date: date)

    # Find or create venue
    venue = find_or_create_venue(pnet_show)

    # Update show attributes
    show.venue = venue if venue
    show.venue_name = pnet_show["venue"] || "Unknown Venue"

    # Find existing tour - tour is required for all shows
    tour_name = pnet_show["tourname"] || pnet_show["tour_name"] || "Not Part of a Tour"
    tour = find_tour_by_name(tour_name)
    unless tour
      puts "\nMissing tour: #{tour_name} for show #{pnet_show['showdate']}"
      puts "Please create this tour manually and re-run the sync."
      exit 1
    end
    show.tour = tour

    # Set show as published but check audio status
    show.published = true

    # If show is new and has no tracks, it's missing audio
    if show.new_record?
      show.audio_status = "missing"
      # Note: incomplete field is computed from audio_status, no need to set it
    end

    show.save!

    if !show.has_audio?
      if show.tracks.any?
        if setlist_differs_from_local?(show)
          show.tracks.destroy_all
          fetch_and_process_setlist(show)
        end
      else
        fetch_and_process_setlist(show)
      end
    else
      # puts "  Show #{show.date} already has audio - skipping setlist processing"
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

    # Hardcoded venue mappings
    venue_mappings = {
      "Les Foufounes Ãlectriques" => "Les Foufounes Électriques",
      "Les Foufounes Ã\u0089lectriques" => "Les Foufounes Électriques",
      "Worcester Centrum Centre" => "The Centrum",
      "The Fox Theatre" => "Fox Theatre",
      "Harris-Millis Cafeteria - University of Vermont" => "Harris-Millis Cafeteria, University of Vermont",
      "Summerstage at Sugarbush North" => "Summer Stage at Sugarbush",
      "Deer Creek Music Center" => "Deer Creek",
      "GTE Virginia Beach Amphitheater" => "Virginia Beach Amphitheater",
      "The â\u0080\u009CEâ\u0080\u009D Center" => "The E Center",
      "Meadows Music Theatre" => "The Meadows",
      "Blockbuster Desert Sky Pavilion" => "Desert Sky Pavilion",
      "FirstMerit Bank Pavilion at Northerly Island" => "Northerly Island",
      "NBC Television Studios, Studio 6A" => "NBC Studios",
      "NBC Television Studios, Studio 6B" => "NBC Studios",
      "ALLTEL Pavilion" => "ALLTEL Pavilion at Walnut Creek",
      "Post-Gazette Pavilion" => "Post-Gazette Pavilion at Star Lake",
      "The Wharf Amphitheater" => "Amphitheater at the Wharf",
      "Pine Knob Music Theatre" => "Pine Knob",
    }

    # Special venue and city mappings for cases where both name and city differ
    # Check both original (broken UTF-8) and fixed versions
    venue_city_mappings = {
      ["Summerstage at Sugarbush North", "Fayston"] => ["Summer Stage at Sugarbush", "North Fayston"],
      ["The Orpheum Theatre", "Vancouver, British Columbia"] => ["The Orpheum", "Vancouver"],
      ["Hurricane Festival", "ScheeÃ\u009Fel"] => ["Hurricane Festival", "Scheeßel"],
      ["GM Place", "Vancouver, British Columbia"] => ["GM Place", "Vancouver"],
      ["Austin360 Amphitheater", "Del Valle"] => ["Austin360 Amphitheater", "Austin"]
    }

        # Check for venue and city mapping first - use original (broken UTF-8) values for mapping
    venue_city_key = [original_venue_name, original_city]
    if venue_city_mappings.key?(venue_city_key)
      mapped_venue_name, mapped_city = venue_city_mappings[venue_city_key]
      venue = Venue.where("lower(name) = ? AND lower(city) = ?", mapped_venue_name.downcase, mapped_city.downcase).first
      return venue if venue
    end

    # Check if we have a hardcoded venue name mapping - use original venue name for mapping
    if venue_mappings.key?(original_venue_name)
      mapped_venue_name = venue_mappings[original_venue_name]
      venue = Venue.left_outer_joins(:venue_renames)
                   .where(
                     "(venues.name = :name OR venue_renames.name = :name) AND lower(venues.city) = :city",
                     name: mapped_venue_name,
                     city: city.downcase
                   ).first
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
                     country: country
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

  def find_tour_by_name(tour_name)
    # First try exact match
    tour = Tour.find_by(name: tour_name)
    return tour if tour

    # Hardcoded mappings for specific tour names
    hardcoded_mappings = {
      "1997 Fall Tour (a.k.a. Phish Destroys America)" => "Fall Tour 1997",
      "2003 20th Anniversary Run" => "20th Anniversary Run",
      "2022 Madison Square Garden Spring Run" => "MSG Spring Run 2022"
    }

    if hardcoded_mappings.key?(tour_name)
      alternative_name = hardcoded_mappings[tour_name]
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # puts "  Trying to match tour: '#{tour_name}'"

    # Handle NYE Run patterns: various formats -> "New Years Run YYYY"
    # Matches: "YYYY NYE Run", "YYYY NYE", "YYYY/YYYY+1 NYE Run", "YYYY/YYYY+1 Inverted NYE Run"
    if match = tour_name.match(/^(\d{4})(?:\/\d{4})?\s+(?:Inverted\s+)?NYE(?:\s+Run)?$/i)
      year = match[1]
      alternative_name = "New Years Run #{year}"
      # puts "  Trying NYE pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # Handle "YYYY/YYYY+1 New Year's Run" pattern
    if match = tour_name.match(/^(\d{4})(?:\/\d{4})?\s+New\s+Year'?s?\s+Run$/i)
      year = match[1]
      alternative_name = "New Years Run #{year}"
      # puts "  Trying New Year's Run pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # Also try with "New Year's" (with apostrophe)
    if match = tour_name.match(/^(\d{4})(?:\/\d{4})?\s+(?:Inverted\s+)?NYE(?:\s+Run)?$/i)
      year = match[1]
      alternative_name = "New Year's Run #{year}"
      # puts "  Trying NYE pattern with apostrophe: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    if match = tour_name.match(/^New\s+Years\s+Run\s+(\d{4})$/i)
      year = match[1]
      alternative_name = "#{year} NYE Run"
      # puts "  Trying reverse NYE pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # Handle season patterns: "YYYY Season" -> "Season Tour YYYY"
    if match = tour_name.match(/^(\d{4})\s+(Spring|Summer|Fall|Winter)$/i)
      year = match[1]
      season = match[2]
      alternative_name = "#{season} Tour #{year}"
      # puts "  Trying season pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # Handle location patterns: "YYYY Location" -> "Location Run YYYY"
    # Common locations: Mexico, Japan, Europe, etc.
    if match = tour_name.match(/^(\d{4})\s+(Mexico|Japan|Europe|Asia|Australia|UK|Caribbean)$/i)
      year = match[1]
      location = match[2]
      alternative_name = "#{location} Run #{year}"
      # puts "  Trying location pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # If tour name matches pattern "YYYY Tour Name", try "Tour Name YYYY" format
    if tour_name.match?(/^\d{4}\s+(.+)/)
      year = tour_name[0..3]
      rest_of_name = tour_name[5..-1]
      alternative_name = "#{rest_of_name} #{year}"
      # puts "  Trying year-first pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    # If tour name matches pattern "Tour Name YYYY", try "YYYY Tour Name" format
    if tour_name.match?(/^(.+)\s+\d{4}$/)
      parts = tour_name.split
      year = parts.last
      rest_of_name = parts[0..-2].join(" ")
      alternative_name = "#{year} #{rest_of_name}"
      # puts "  Trying year-last pattern: '#{alternative_name}'"
      tour = Tour.find_by(name: alternative_name)
      return tour if tour
    end

    puts "  No match found for: '#{tour_name}'"
    nil
  end

  def fetch_and_process_setlist(show)
    # Fetch setlist data from dedicated setlists endpoint
    response = Typhoeus.get(
      "https://api.phish.net/v5/setlists/showdate/#{show.date.strftime('%Y-%m-%d')}.json",
      params: { apikey: ENV.fetch("PNET_API_KEY", nil) }
    )

    if response.success?
      data = JSON.parse(response.body)
      if data["data"] && data["data"].any?
        setlist_data = data["data"]
        # puts "  Processing setlist for #{show.date} (#{setlist_data.length} sets)"
        process_setlist(show, setlist_data)
      else
        # puts "  No setlist data available for #{show.date}"
      end
    else
      puts "  Error fetching setlist data for #{show.date}: #{response.code}"
    end
  end

    def process_setlist(show, setlist_data)
    tracks_created = 0

    # Filter setlist_data to only include Phish tracks (exclude guest appearances)
    phish_tracks = setlist_data.select { |song_data| song_data["artist_slug"] == "phish" }

    # phish_tracks is a flat array of song records, each with position and set info
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

    puts "    Created #{tracks_created} tracks for #{show.date}"
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
      'Ã¡' => 'á',  # á
      'Ã©' => 'é',  # é
      'Ã­' => 'í',  # í
      'Ã³' => 'ó',  # ó
      'Ãº' => 'ú',  # ú
      'Ã±' => 'ñ',  # ñ
      'Ã¼' => 'ü',  # ü
      'Ã¤' => 'ä',  # ä
      'Ã¶' => 'ö',  # ö
      'Ã ' => 'à',  # à
      'Ã¨' => 'è',  # è
      'Ã¬' => 'ì',  # ì
      'Ã²' => 'ò',  # ò
      'Ã¹' => 'ù',  # ù
      'Ã¢' => 'â',  # â
      'Ãª' => 'ê',  # ê
      'Ã®' => 'î',  # î
      'Ã´' => 'ô',  # ô
      'Ã»' => 'û',  # û
      'Ã‡' => 'Ç',  # Ç
      'Ã†' => 'Æ',  # Æ
      'Ã˜' => 'Ø',  # Ø
      'Ã…' => 'Å',  # Å
      'ÃŸ' => 'ß',  # ß
      'Ãe' => 'ße',  # ße (for ScheeÃel -> Scheeßel)
      "Ã\u0089" => 'É',  # É (Unicode escape sequence)
      "â\u0080\u0099" => "'"  # Right single quote (mangled UTF-8)
    }

    fixed_text = text.dup
    utf8_fixes.each do |broken, correct|
      fixed_text.gsub!(broken, correct)
    end

    fixed_text
  end

  def setlist_differs_from_local?(show)
    # Fetch current setlist from Phish.net
    response = Typhoeus.get(
      "https://api.phish.net/v5/setlists/showdate/#{show.date.strftime('%Y-%m-%d')}.json",
      params: { apikey: ENV.fetch("PNET_API_KEY", nil) }
    )

    return false unless response.success?

    data = JSON.parse(response.body)
    return false unless data["data"] && data["data"].any?

    # Filter to only include Phish tracks (exclude guest appearances)
    remote_setlist = data["data"].select { |song_data| song_data["artist_slug"] == "phish" }
    local_tracks = show.tracks.includes(:songs).order(:position)

    # Compare track counts
    return true if remote_setlist.length != local_tracks.length

    # Compare each track
    remote_setlist.each_with_index do |song_data, index|
      local_track = local_tracks[index]

            # Compare track title (case insensitive, with whitespace trimmed)
      # We compare against track.title because that's what's actually stored when creating tracks
      remote_title = song_data["song"]&.downcase&.strip
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
end
# rubocop:enable Rake/MethodDefinitionInTask
