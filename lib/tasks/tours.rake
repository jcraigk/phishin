namespace :tours do

  #########################################################
  # This task scrapes phish.net for tour information and associated shows
  # It updates or creates tours as necessary
  # It tries to sync show/tour associations
  desc "Sync Tours with phish.net"
  task :sync => :environment do

    require 'nokogiri'
    require 'open-uri'

    url = "http://www.phish.net/tour"
    puts "Scraping #{url} ..."
    
    num_created = 0
    num_updated = 0
    num_shows_found = 0
    missing_shows = []
    
    # Pull in basic details of all venues
    rows = Nokogiri::HTML(open(url)).css('#mainContent ul li')
    tour_list = rows.collect do |row|
      detail = {}
      [
        [:name, 'a/text()'],
        [:url, 'a/@href'],
      ].each do |name, xpath|
        detail[name] = Iconv.conv('utf-8', 'latin1', row.at_xpath(xpath).to_s.strip)
      end
      detail
    end
    
    # Create/update venue records
    tour_list.each_with_index do |v, i|
      unless v[:name].empty?
        tour = Tour.where("name = ?", v[:name]).first
        tour_attributes = v.reject{|k,v| !Tour.new.attributes.keys.member?(k.to_s)}
        if tour
          tour.update_attributes(tour_attributes)
          num_updated += 1
          puts "#{i} of #{tour_list.size} :: Updated " + v[:name]
        else
          tour = Tour.new(tour_attributes)
          tour.save
          num_created += 1
          puts "#{i} of #{tour_list.size} :: Created " + v[:name]
        end
      end
    end
    puts "TOURS: " + num_updated.to_s + " updated, " + num_created.to_s + " created"
    puts "=============================================="
    puts "=============================================="
    
    # Get list of shows for each venue
    # WARNING: This cannot handle multiple shows on a single day...only one will have the correct venue association
    tour_list.each_with_index do |v, i|
      unless v[:url].empty? or v[:name].empty?
        url = "http://www.phish.net" + v[:url]
        puts "#{i+1} of #{tour_list.size} :: Scraping #{url}"
        tour = Tour.where("name = ?", v[:name]).first
        rows = Nokogiri::HTML(open(url)).css('#mainContent ul li')
        date_list = rows.collect { |row| Iconv.conv('utf-8', 'latin1', row.at_xpath('a[1]/text()').to_s.strip) }
        date_list.each do |date|
          show = Show.where("show_date = ?", date).first
          if show
            num_shows_found += 1
            show.tour = tour
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