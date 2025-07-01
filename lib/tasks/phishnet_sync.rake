namespace :phishnet do
  desc "Sync all known Phish show dates from Phish.net"
  task sync_shows: :environment do
    puts "Starting Phish.net sync..."

    # Get all known dates from Phish.net
    response = Typhoeus.get(
      "https://api.phish.net/v5/shows.json",
      params: {
        apikey: Rails.application.credentials.dig(:phishnet, :api_key),
        order_by: "showdate"
      }
    )

    if response.success?
      data = JSON.parse(response.body)
      shows_data = data["data"]

      puts "Found #{shows_data.length} shows on Phish.net"

      shows_data.each_with_index do |pnet_show, index|
        begin
          process_phishnet_show(pnet_show)
          print "." if index % 10 == 0
        rescue StandardError => e
          puts "\nError processing show #{pnet_show['showdate']}: #{e.message}"
        end
      end

      puts "\nSync complete!"
    else
      puts "Error fetching data from Phish.net: #{response.code}"
    end
  end

  desc "Sync a specific date range from Phish.net"
  task :sync_date_range, [:start_date, :end_date] => :environment do |t, args|
    start_date = Date.parse(args[:start_date])
    end_date = Date.parse(args[:end_date])

    puts "Syncing shows from #{start_date} to #{end_date}..."

    (start_date..end_date).each do |date|
      response = Typhoeus.get(
        "https://api.phish.net/v5/shows/showdate/#{date.strftime('%Y-%m-%d')}.json",
        params: { apikey: Rails.application.credentials.dig(:phishnet, :api_key) }
      )

      if response.success?
        data = JSON.parse(response.body)
        if data["data"] && data["data"].any?
          process_phishnet_show(data["data"].first)
          print "."
        end
      end
    end

    puts "\nSync complete!"
  end

  private

  def process_phishnet_show(pnet_show)
    date = Date.parse(pnet_show["showdate"])
    show = Show.find_or_initialize_by(date: date)

    # Find or create venue
    venue = find_or_create_venue(pnet_show)

    # Update show attributes
    show.venue = venue if venue
    show.venue_name = pnet_show["venue"] || "Unknown Venue"

    # Find or create tour
    if pnet_show["tourid"].present? && pnet_show["tourname"].present?
      tour = find_or_create_tour(pnet_show)
      show.tour = tour if tour
    end

    # Set show as published but check audio status
    show.published = true

    # If show is new and has no tracks, it"s missing audio
    if show.new_record?
      show.audio_status = "missing"
      # Note: incomplete field is computed from audio_status, no need to set it
    end

    show.save!

    # Process setlist if available and show has missing audio
    if pnet_show["setlistdata"].present? && show.missing_audio?
      process_setlist(show, pnet_show["setlistdata"])
    end
  end

  def find_or_create_venue(pnet_show)
    return nil unless pnet_show["venue"].present?

    venue_name = pnet_show["venue"]
    city = pnet_show["city"] || "Unknown"
    state = pnet_show["state"] || pnet_show["country"] || "Unknown"
    country = pnet_show["country"] || "USA"

    # Try to find existing venue
    venue = Venue.find_by(
      "lower(name) = ? AND lower(city) = ?",
      venue_name.downcase,
      city.downcase
    )

    return venue if venue

    # Create new venue
    Venue.create!(
      name: venue_name,
      city: city,
      state: state,
      country: country,
      slug: venue_name.parameterize
    )
  rescue ActiveRecord::RecordInvalid => e
    puts "\nCould not create venue #{venue_name}: #{e.message}"
    nil
  end

  def find_or_create_tour(pnet_show)
    tour_name = pnet_show["tourname"]

    tour = Tour.find_by(name: tour_name)
    return tour if tour

    # Try to determine tour dates from the tour name or use show date
    year = pnet_show["showdate"][0..3]
    starts_on = Date.parse("#{year}-01-01")
    ends_on = Date.parse("#{year}-12-31")

    Tour.create!(
      name: tour_name,
      starts_on: starts_on,
      ends_on: ends_on,
      slug: tour_name.parameterize
    )
  rescue ActiveRecord::RecordInvalid => e
    puts "\nCould not create tour #{tour_name}: #{e.message}"
    nil
  end

  def process_setlist(show, setlist_data)
    position = 1

    setlist_data.each do |set_data|
      set_name = set_data["name"] || "Set 1"
      set_code = case set_name.downcase
                 when /encore|e$/i then "E"
                 when /set\s*1|i$/i then "1"
                 when /set\s*2|ii$/i then "2"
                 when /set\s*3|iii$/i then "3"
                 when /set\s*4|iv$/i then "4"
                 else "S"
                 end

      set_data["songs"].each do |song_data|
        song = find_or_create_song(song_data)
        next unless song

        # Create track with missing audio
        track = show.tracks.create!(
          title: song_data["song"] || song.title,
          position: position,
          set: set_code,
          audio_status: "missing",
          slug: "#{position}-#{song.slug}"
        )

        # Create song association
        track.songs << song

        position += 1
      end
    end
  end

  def find_or_create_song(song_data)
    song_title = song_data["song"]
    return nil unless song_title.present?

    # Try to find existing song (case insensitive)
    song = Song.where("lower(title) = ?", song_title.downcase).first
    return song if song

    # Create new song
    Song.create!(
      title: song_title,
      slug: song_title.parameterize,
      original: true # Default to original, can be updated later
    )
  rescue ActiveRecord::RecordInvalid => e
    puts "\nCould not create song #{song_title}: #{e.message}"
    nil
  end
end
