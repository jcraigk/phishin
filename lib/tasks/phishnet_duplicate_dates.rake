namespace :phishnet do
  desc "Analyze PhishNet API data for duplicate dates"
  task duplicate_dates: :environment do
    require "net/http"
    require "json"

    puts "Fetching PhishNet show data..."

    # Fetch data from PhishNet API
    uri = URI("https://api.phish.net/v5/shows/artist/phish.json?order_by=showdate&apikey=448345A7B7688DDE43D0")
    response = Net::HTTP.get_response(uri)

    if response.code != "200"
      puts "Error fetching data: #{response.code} - #{response.message}"
      exit 1
    end

    data = JSON.parse(response.body)

    if data["error"]
      puts "API Error: #{data['error_message']}"
      exit 1
    end

    shows = data["data"]
    puts "Total shows in API: #{shows.length}"

    # Filter out shows with exclude_from_stats = 1
    valid_shows = shows.reject { |show| show["exclude_from_stats"] == 1 }
    puts "Valid shows (exclude_from_stats != 1): #{valid_shows.length}"

    # Group by showdate and count duplicates
    date_counts = valid_shows.group_by { |show| show["showdate"] }
                            .transform_values(&:count)
                            .select { |date, count| count > 1 }
                            .sort_by { |date, count| date }

    puts "\nDuplicate dates found:"
    puts "====================="

    if date_counts.empty?
      puts "No duplicate dates found!"
    else
      date_counts.each do |date, count|
        puts "#{date}: #{count} shows"

        # Show details for each duplicate
        duplicate_shows = valid_shows.select { |show| show["showdate"] == date }
        duplicate_shows.each do |show|
          puts "  - #{show['venue']} (#{show['city']}, #{show['state']})"
        end
        puts
      end

      puts "Total duplicate dates: #{date_counts.length}"
      puts "Total duplicate shows: #{date_counts.map { |date, count| count }.sum}"
    end
  end
end
