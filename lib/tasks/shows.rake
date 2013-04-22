namespace :shows do
  
  desc "Apply SBD tags to shows"
  task :apply_sbd_tags => :environment do
    # dates = %w(2011-5-26 2011-6-30)
    # dates = %w(2010-3-15 2009-10-29)
    # dates = %w(2002-12-14 2002-12-19)
    # dates = %w(2000-5-15 2000-5-18 2000-5-19 2000-5-23 2000-6-15 2000-6-16 2000-7-10 2000-7-11 2000-7-17)
    # dates = %w(1999-7-30 1999-7-31 1999-8-1)
    # dates = %w(1998-5-7 1998-7-8 1998-7-24 1998-7-26 1998-8-8 1998-8-14 1998-8-16 1998-10-3 1998-10-20 1998-10-27 1998-11-3 1998-12-29)
    # dates = %w(1997-2-16 1997-2-20 1997-2-26 1997-3-5 1997-6-22 1997-8-16 1997-8-17 1997-11-28 1997-12-11)
    # dates = %w(1996-6-6 1996-7-11 1996-8-16 1996-8-17 1996-12-31)
    # dates = %w(1995-6-25 1996-7-1)
    # dates = %w(1994-4-13 1994-4-17 1994-4-25 1994-4-26 1994-5-7 1994-5-14 1994-5-22 1994-6-16 1994-6-18 1994-6-22 1994-10-18 1994-10-29 1994-12-30)
    # dates = %w(1993-2-18 1993-2-20 1993-2-27 1993-3-9 1993-3-22 1993-3-28 1993-4-9 1993-4-10 1993-4-12 1993-4-17 1993-4-18 1993-5-1 1993-5-2 1993-5-5 1993-5-6 1993-5-30 1993-7-23 1993-7-25 1993-8-20 1993-8-24 1993-12-30 1993-12-31)
    # dates = %w(1992-3-6 1992-3-13 1992-3-14 1992-3-20 1992-3-22 1992-3-25 1992-4-3 1992-4-6 1992-4-12 1992-4-13 1992-4-15 1992-4-16 1992-4-17 1992-4-18 1992-4-21 1992-4-22 1992-4-24 1992-4-25 1992-5-18 1992-6-19 1992-6-20 1992-6-23 1992-6-24 1992-7-11 1992-7-15 1992-7-21 1992-7-23 1992-7-24 1992-7-25 1992-8-13 1992-8-14 1992-8-15 1992-8-17 1992-8-29 1992-11-19 1992-11-20 1992-12-5 1992-12-12 1992-12-29)
    # dates = %w(1991-2-1 1991-2-7 1991-2-8 1991-2-21 1991-3-1 1991-3-13 1991-3-16 1991-3-17 1991-3-22 1991-3-23 1991-4-4 1991-4-5 1991-4-6 1991-4-11 1991-4-12 1991-4-14 1991-4-16 1991-4-21 1991-4-27 1991-5-3 1991-7-11 1991-7-14 1991-7-15 1991-7-21 1991-7-23 1991-7-25 1991-10-4- 1991-10-6 1991-10-10 1991-10-11 1991-10-12 1991-10-13 1991-10-18 1991-10-19 1991-10-24 1991-10-28 1991-11-1 1991-11-2 1991-11-30 1991-12-5 1991-12-6 1991-12-7 1991-12-31)
    # dates = %w(1990-1-26 1990-1-27 1990-1-28 1990-2-5 1990-2-9 1990-2-15 1990-2-16 1990-2-17 1990-2-22 1990-2-23 1990-2-24 1990-3-1 1990-3-3 1990-3-7 1990-3-8 1990-3-9 1990-3-10 1990-3-11 1990-3-17 1990-3-28 1990-4-4 1990-4-5 1990-4-6 1990-4-7 1990-4-9 1990-4-18 1990-4-20 1990-4-21 1990-4-22 1990-4-25 1990-4-26 1990-5-4 1990-5-6 1990-5-10 1990-5-13 1990-5-19 1990-5-23 1990-5-24 1990-6-5 1990-6-8 1990-6-9 1990-6-17 1990-9-13 1990-9-29 1990-10-4 1990-10-6 1990-10-7 1990-10-31 1990-11-2 1990-11-4 1990-11-8 1990-11-10 1990-11-16 1990-11-24 1990-11-28)
    # dates = %w(1989-1-26 1989-2-6 1989-2-7 1989-2-24 1989-3-12 1989-3-14 1989-3-30 1989-4-14 1989-4-20 1989-5-5 1989-5-9 1989-5-13 1989-5-20 1989-5-21 1989-5-26 1989-5-28 1989-6-10 1989-6-23 1989-6-29 1989-6-30 1989-8-17 1989-8-19 1989-8-26 1989-9-9 1989-9-21 1989-10-1 1989-10-7 1989-10-10 1989-10-13 1989-10-20 1989-10-21 1989-10-22 1989-10-26 1989-10-31 1989-11-3 1989-11-9 1989-11-10 1989-11-11 1989-11-16 1989-11-30 1989-12-1 1989-12-3 1989-12-8 1989-12-9 1989-12-15 1989-12-29 1989-12-30)
    # dates = %w(1988-1-27 1988-2-26 1988-3-12 1988-5-14 1988-5-15 1988-5-23 1988-5-24 1988-6-15 1988-6-19 1988-6-21 1988-7-11 1988-7-12 1988-7-23 1988-7-24 1988-7-25 1988-7-29 1988-7-30 1988-8-3 1988-8-5 1988-8-13 1988-8-27 1988-9-8 1988-9-13 1988-9-24 1988-10-29 1988-11-3 1988-11-5 1988-11-11 1988-12-10 1988-12-17)
    dates = %w(1983-12-2 1984-12-1 1985-3-4 1985-5-3 1985-10-17 1985-10-30 1985-11-19 1985-11-23 1986-4-15 1986-10-15 1986-10-31 1986-12-6 1987-3-6 1987-3-23 1987-4-29 1987-8-29 1987-9-2 1987-10-14 1987-11-19)
    dates.each do |date|
      if show = Show.where(date: date).first
        tag_names = show.tags.map(&:name)
        if tag_names.include? 'sbd'
          puts "#{date}: Already has SBD tag"
        else
          ShowTag.create(show_id: show.id, tag_id: 1)
          puts "#{date}: Created SBD tag"
        end
        if tracks = show.tracks
          tracks.each do |track|
            tag_names = track.tags.map(&:name)
            if tag_names.include? 'SBD'
              puts "#{date} / #{track.title}: Already has SBD tag"
            else
              TrackTag.create(track_id: track.id, tag_id: 1)
              puts "#{date} / #{track.title}: Created SBD tag"
            end
          end
        end
      end
    end
  end
  
  desc "Set shows.duration based on sum of all tracks"
  task :calc_duration => :environment do
    Show.order('date desc').all.each do |show|
      tracks = show.tracks
      if tracks.present?
        duration = show.tracks.map(&:duration).inject(0, &:+)
        show.duration = duration
        show.save
        puts "#{show.date}: #{duration}"
      end
    end
  end
  
  # Get info about each show from the spreadsheet
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

  # Get songs from pnet api
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
          date = show_data["showdate"]
          unless Show.find_by_date(date)
            missing_list[year] << date
            # Show.create(date: date)
          end
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