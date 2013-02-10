namespace :shows do 
  task :get_shows_info => :environment do
    require 'open-uri'

    SHOW_LIST_URL = 'https://spreadsheets.google.com/spreadsheet/pub?key=0AjeIQ6qQvexzcDhXS2twUC1US3BPMVZuUWdjZmY2RVE&gid=15'
    idxs = {
      date: 1, 
      sbd: 2, 
      venue: 4,
      city: 5,
      state: 6,
      link: 7
    }

    doc         = Nokogiri::HTML(open(SHOW_LIST_URL))
    songTable   = doc.at_css('table#tblMain')
    firstRowIdx = 7

    rows = doc.css('tr')[firstRowIdx..-1]

    rows.each do |row|
      fields = row.children
      unless fields[idxs[:date]].content.blank?
        p "#{fields[idxs[:date]].content} -- #{fields[idxs[:venue]].content} - #{fields[idxs[:city]].content}, #{fields[idxs[:state]].content}"
      end
    end
  end

  task :get_songs => :environment do
    require 'pnet'
    api_key = '448345A7B7688DDE43D0'

    pnet = PNet.new api_key
    setlist = pnet.shows_setlists_get('showdate' => ENV['date'])[0]; 
    songs = Nokogiri::HTML(setlist["setlistdata"]).css('p.pnetset > a').map(&:content)

    songs.each_with_index do |song, i|
      p "#{i + 1}. #{song}"
    end
  end
  
  desc "Using phish.net, get list of shows we don't currently have audio for"
  task :missing_report => :environment do
    require 'open-uri'
    require 'nokogiri'
    require_relative '../pnet'
    
    PNET_API_KEY = '448345A7B7688DDE43D0'
    pnet  = PNet.new PNET_API_KEY
    
    total_shows = {}
    missing_list = {}
    (1983..Time.now.year).each do |year|
      total_shows[year] = 0
      missing_list[year] = []
      data = pnet.shows_query('year' => year);
      data.each do |show_data|
        unless show_data[1] == 0 or show_data[1] == "No Shows Found"
          total_shows[year] += 1
          show_date = show_data["showdate"]
          missing_list[year] << show_date unless Show.find_by_show_date(show_date)
        end
      end
      num_missing = missing_list[year].size
      percent = (total_shows[year] > 0 ? (num_missing.to_f / total_shows[year].to_f) * 100.0 : 0)
      puts "#{year}: missing #{num_missing} of #{total_shows[year]} (#{percent.round}%)"
    end
    total_missing = 0
    missing_list.each {|y, a| total_missing += a.size}
    overall_total_shows = 0
    total_shows.each {|y, num| overall_total_shows += num }
    percent = (overall_total_shows > 0 ? (total_missing.to_f / overall_total_shows.to_f) * 100.0 : 0)
    puts "TOTAL: missing #{total_missing} of #{overall_total_shows} (#{percent.round}%)"

  end
  
  
  
  
  
  
  
  
  
  
  
  
  
end