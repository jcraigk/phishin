namespace :venues do

  #########################################################
  # This task scrapes phish.net for venue information and associated shows
  # It updates or creates venues as necessary
  # It tries to sync show/venue associations
  desc "Sync Venues with phish.net"
  task :sync => :environment do
    
    require 'nokogiri'
    require 'open-uri'

    url = "http://www.phish.net/venues"
    puts "Scraping #{url} ..."
    
    num_created = 0
    num_updated = 0
    num_shows_found = 0
    missing_shows = []
    
    # Pull in basic details of all venues
    rows = Nokogiri::HTML(open(url)).css('table tr')
    venue_list = rows.collect do |row|
      detail = {}
      [
        [:name, 'td[1]/a/text()'],
        [:url, 'td[1]/a/@href'],
        [:city, 'td[2]/text()'],
        [:state, 'td[3]/text()'],
        [:country, 'td[4]/text()'],
        [:show_count, 'td[5]/text()'],
        [:first_date, 'td[6]/a/text()'],
        [:last_date, 'td[7]/a/text()']
      ].each do |name, xpath|
        detail[name] = Iconv.conv('utf-8', 'latin1', row.at_xpath(xpath).to_s.strip)
      end
      detail
    end
    
    # Create/update venue records
    venue_list.each_with_index do |v, i|
      unless v[:name].empty?
        venue = Venue.where("name = ?", v[:name]).first
        venue_attributes = v.reject{|k,v| !Venue.new.attributes.keys.member?(k.to_s)}
        if venue
          venue.update_attributes(venue_attributes)
          num_updated += 1
          puts "#{i} of #{venue_list.size} :: Updated " + v[:name]
        else
          venue = Venue.new(venue_attributes)
          venue.save
          num_created += 1
          puts "#{i} of #{venue_list.size} :: Created " + v[:name]
        end
      end
    end
    puts "VENUES: " + num_updated.to_s + " updated, " + num_created.to_s + " created"
    puts "=============================================="
    puts "=============================================="
    
    # Get list of shows for each venue
    # WARNING: This cannot handle multiple shows on a single day...only one will have the correct venue association
    venue_list.each_with_index do |v, i|
      unless v[:url].empty? or v[:name].empty?
        url = "http://www.phish.net" + v[:url]
        puts "#{i+1} of #{venue_list.size} :: Scraping #{url}"
        venue = Venue.where("name = ?", v[:name]).first
        rows = Nokogiri::HTML(open(url)).css('#mainContent ul li')
        date_list = rows.collect { |row| Iconv.conv('utf-8', 'latin1', row.at_xpath('a[1]/text()').to_s.strip) }
        date_list.each do |date|
          show = Show.where("show_date = ?", date).first
          if show
            num_shows_found += 1
            show.venue = venue
            show.save
            puts "Show associated: #{date}"
          else
            missing_shows << date
            puts "Show missing: #{date}"
          end
        end
        
      end
    end

    puts "Missing shows: " + missing_shows.to_s
    
  end
  
end