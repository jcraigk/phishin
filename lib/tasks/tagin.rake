# frozen_string_literal: true
require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'csv'

namespace :tagin do
  desc 'Sync data from remote spreadsheet'
  task sync: :environment do
    TAGIN_TAGS.each do |tag_name|
      puts '========================'
      puts " Syncing Tag: #{tag_name}"
      puts '========================'

      range = "#{tag_name}!A1:G5000"
      data = GoogleSpreadsheetFetcher.new(ENV['TAGIN_GSHEET_ID'], range, headers: true).call

      TrackTagSyncService.new(tag_name, data).call
    end
  end

  desc 'Sync jam_starts_at_second data from spreadsheet'
  task jamstart: :environment do
    include Syncable

    data = GoogleSpreadsheetFetcher.new(ENV['TAGIN_GSHEET_ID'], "JAMSTART!A1:G5000", headers: true).call
    data.each do |row|
      @track = find_track_by_url(row['URL'])
      next puts "Invalid track: #{row['URL']}" if @track.blank?
      @track.update(jam_starts_at_second: seconds_or_nil(row['Starts At']))
      print '.'
    end
  end

  desc 'Provide links to tracks based on song'
  task songs: :environment do
    SONG_TITLES = [
      'The Haunted House',
      'The Very Long Fuse',
      'The Dogs',
      'Timber',
      'Your Pet Cat',
      'Shipwreck',
      'The Unsafe Bridge',
      'The Chinese Water Torture',
      'The Birds',
      'Martian Monster',
      'We Are Come to Outlive Our Brains'
    ].freeze

    SONG_TITLES.each do |title|
      song = Song.find_by!(title: title)
      song.tracks.find_each do |track|
        puts track.url
      end
    end
  end

  desc 'Apply Costume tag to shows and tracks'
  task costume: :environment do
    tag = Tag.find_by(name: 'Costume')
    show_data = {
      '1994-10-31' => 'The White Album by The Beatles',
      '1996-10-31' => 'Remain In Light by Talking Heads',
      '1998-10-31' => 'Loaded by The Velvet Underground ',
      '1998-11-02' => 'Dark Side of the Moon by Pink Floyd',
      '2009-10-31' => 'Exile on Main St. by The Rolling Stones',
      '2010-10-31' => 'Waiting for Columbus by Little Feat',
      '2014-10-31' => 'Chilling, Thrilling Sounds of the Haunted House by Disneyland/Phish',
      '2016-10-31' => 'The Rise and Fall of Ziggy Stardust and the Spiders From Mars by David Bowie',
      '2018-10-31' => 'i Rokk by Kasvot Växt (Phish)'
    }
    # Exclude standard songs surrounding 1998-11-02 Dark Side of the Moon
    blacklist_track_ids = [17952, 17953, 17954, 17955, 17956, 17966]

    # Clear existing
    ShowTag.where(tag_id: tag.id).destroy_all
    TrackTag.where(tag_id: tag.id).destroy_all

    # Apply show and track tags
    show_data.each do |date, notes|
      show = Show.find_by(date: date)
      ShowTag.create(show: show, tag: tag, notes: notes)
      Track.where(show_id: show.id, set: '2')
           .where
           .not(id: blacklist_track_ids)
           .order(position: :asc)
           .each do |track|
        TrackTag.create(track: track, tag: tag, notes: notes)
        puts track.url
      end
    end
  end

  desc 'Apply Gamehendge tag to shows and tracks'
  task gamehendge: :environment do
    tag = Tag.find_by(name: 'Gamehendge')
    show_data = {
      '1988-03-12' => 'First live Gamehendge',
      '1991-10-13' => 'Second live Gamehendge',
      '1993-03-22' => 'Third live Gamehendge',
      '1994-06-26' => 'Fourth live Gamehendge',
      '1994-07-08' => 'Fifth live Gamehendge'
    }
    blacklist_track_ids = [7818, 7828, 10079, 10080, 10081, 10094, 10095, 10096, 5968, 5969, 5986, 5987, 5988]

    # Clear existing
    ShowTag.where(tag_id: tag.id).destroy_all
    TrackTag.where(tag_id: tag.id).destroy_all

    # Apply show and track tags
    show_data.each do |date, notes|
      show = Show.find_by(date: date)
      ShowTag.create(show: show, tag: tag, notes: notes)
      set = date == '1993-03-22' ? '2' : '1'
      Track.where(show_id: show.id, set: set)
           .where
           .not(id: blacklist_track_ids)
           .order(position: :asc)
           .each do |track|
        TrackTag.create(track: track, tag: tag, notes: notes)
        puts track.url
      end
    end
  end

  desc 'Pull data from remote narration spreadsheet'
  # Track not found: 1989-08-26 / Fly Famous Mockingbird (incomplete show)
  # Track not found: 1990-04-04 / Rhombus Narration (narration not present this show)
  # Track not found: 1991-11-10 / Llama (no recording)
  # Track not found: 1992-04-04 / Harpua (incomplete show)
  task narration: :environment do
    SPREADSHEET_ID = '10boHKbXnR7V5qFCUc7rtDVBrFg-jmgoOWQLcLRWdz6o'
    SPREADSHEET_RANGE = 'Narration Chart!A1:E200'

    data = GoogleSpreadsheetFetcher.new(SPREADSHEET_ID, SPREADSHEET_RANGE).call

    csv_data =
      data.map do |d|
        date = d['date']
        title = d['song']
        show = Show.find_by(date: date)
        track = Track.find_by(show: show, title: title)
        next puts "Track not found: #{date} / #{title} :: #{d['summary']}" unless show && track
        [track.url, '', '', d['summary']]
      end.compact

    CSV.open("#{Rails.root}/tmp/narration.csv", 'w') do |csv|
      csv_data.each do |d|
        csv << d
      end
    end
  end

  desc 'Tease Chart HTML'
  task teases_html: :environment do
    URL = 'https://phish.net/tease-chart'
    response = HTTParty.get(URL)

    tag = Tag.find_by(name: 'Tease')

    headers = %i[song artist times dates]
    data = []
    Nokogiri.HTML(response).search('table').first.search('tr').each_with_index do |tr|
      record = {}
      tr.search('th, td').each_with_index do |cell, cell_idx|
        key = headers[cell_idx]
        record[key] = cell.text.strip
      end
      data << record
    end

    csv_data = []
    data.each do |record|
      record[:dates].split(',').each do |date_song|
        date_song.strip!
        next puts "Skipping #{date_song}" unless date_song =~ /\A(\d{4}-\d{2}-\d{2})(.*)\z/

        date = Regexp.last_match[1].strip
        title = Regexp.last_match[2].strip
        title = title_abbreviations[title] if title_abbreviations[title]

        show = Show.find_by(date: date)
        next puts "Missing show: #{date}" unless show

        track =
          Track.where(show: show)
               .where(
                 'title = ? or title LIKE ? or title LIKE ? or title LIKE ? or title LIKE ?',
                 title,
                 "%> #{title}",
                 "#{title} >%",
                 "%> #{title} >%",
                 "#{title}, %"
               ).first
        next puts "Missing track: #{date} #{title}" unless track

        next if TrackTag.find_by(tag: tag, track: track)

        song = record[:song]
        song += " by #{record[:artist]}" unless record[:artist] == 'Phish'
        csv_data << [track.url, '', '', song, 'Imported from Phish.net Tease Chart']
      end
    end

    CSV.open("#{Rails.root}/tmp/teases_html.csv", 'w') do |csv|
      csv_data.each do |d|
        csv << d
      end
    end

    puts "Processed #{csv_data.size} entries"
  end

  desc 'Pull data from remote tease spreadsheet'
  task teases: :environment do
    SPREADSHEET_ID = '1gtR1yVQXA-4hZ2UEfXMl0bvCNLTmDOICHEXElZ1MK9g'

    # SPREADSHEET_RANGE = 'Tease Chart!A2:I1000'
    SPREADSHEET_RANGE = 'Timings!A2:I1000'

    data = GoogleSpreadsheetFetcher.new(SPREADSHEET_ID, SPREADSHEET_RANGE, headers: false).call

    csv_data = []
    song = ''
    artist = ''
    data.each do |d|
      if d.first.present? # If `Song` field is blank, refers to previous one
        song = d.first
        artist = d.second
      end

      notes = song
      notes += " by #{artist}" if artist.present? && artist != 'Phish'

      (2..8).each do |idx|
        next unless d[idx]

        words = d[idx].split(' ')
        date_parts = words.first.split('/')
        year = date_parts[2].to_i
        year =
          if year < 10
            "200#{year}"
          elsif year < 80
            "20#{year}"
          elsif year < 100
            "19#{year}"
          else
            year
          end
        date = Date.parse("#{year}-#{date_parts.first}-#{date_parts.second}")

        # The last word is not always a time (0:32)
        starts_at = words.last.include?(':') ? words.last : nil
        if starts_at
          starts_at = starts_at.split('/').first if starts_at.include?('/')
          starts_at = starts_at.tr('*', '') if starts_at.include?('*')
        end
        last_title_idx = starts_at ? -2 : -1

        # Title may be abbreviated
        title = words[1..last_title_idx].join(' ')
        title = title_abbreviations[title] if title_abbreviations[title]

        show = Show.find_by(date: date)
        track =
          Track.where(show: show)
               .where(
                 'title = ? or title LIKE ? or title LIKE ? or title LIKE ? or title LIKE ?',
                 title,
                 "%> #{title}",
                 "#{title} >%",
                 "%> #{title} >%",
                 "#{title}, %"
               ).first
        next puts "No match: #{date} / #{title}" unless show && track

        csv_data << [track.url, starts_at, '', notes, 'Imported from Phish.net Tease Chart']
      end
    end
    csv_data.compact!

    CSV.open("#{Rails.root}/tmp/teases.csv", 'w') do |csv|
      csv_data.each do |d|
        csv << d
      end
    end

    puts "Processed #{csv_data.size} entries"
  end

  desc 'Calculate Grind days counts'
  task grind: :environment do
    include ActionView::Helpers::NumberHelper

    first_date = Date.parse('2009-03-06');
    first_days_lived = {
      'Page' => 16_730,
      'Fish' => 16_086,
      'Trey' => 16_228,
      'Mike' => 15_982
    }

    csv_data = []
    Track.joins(:show)
         .where('tracks.title = ?', 'Grind')
         .where('shows.date > ?', first_date)
         .order('shows.date asc')
         .each do |track|
      delta = (track.show.date - first_date).to_i
      total = 0
      notes = first_days_lived.map do |person, count|
        person_total = count + delta
        total += person_total
        "#{person}: #{number_with_delimiter(person_total)} days"
      end.join("\n")
      notes += "\nGrand total: #{number_with_delimiter(total)} days"

      csv_data << [track.url, '', '', notes]
    end

    CSV.open("#{Rails.root}/tmp/grind.csv", 'w') do |csv|
      csv_data.each do |d|
        csv << d
      end
    end
  end

  def title_abbreviations
    {
      "'A' Train" => "Take the 'A' Train",
      "1st Alumni" => "Alumni Blues",
      "1st Antelope" => "Run Like an Antelope",
      "1st Ass Handed" => "Ass Handed",
      "1st BBFCFM" => "Big Black Furry Creature from Mars",
      "1st Bowie" => "David Bowie",
      "1st CDT" => "Chalk Dust Torture",
      "1st Crosseyed" => "Crosseyed and Painless",
      "1st DWD" => "Down with Disease",
      "1st HYHU" => "Hold Your Head Up",
      "1st Love You" => "Love You",
      "1st Mikes" => "Mike's Song",
      "1st Mr. Completely" => "Mr. Completely",
      "1st Seven Below" => "Sevent Below",
      "1st show Bug" => "Bug",
      "1st Tweezer" => "Tweezer",
      "1st YEM" => "You Enjoy Myself",
      "1stAntelope" => "Run Like an Antelope",
      "1stASZ" => "Also Sprach Zarathustra",
      "1stBowie" => "David Bowie",
      "1stCDT" => "Chalk Dust Torture",
      "1stCities" => "Cities",
      "1stCold As Ice" => "Cold as Ice",
      "1stGhost" => "Ghost",
      "1stHarpua" => "Harpua",
      "1stHydrogen" => "I Am Hydrogen",
      "1stHYHU" => "Hold Your Head Up",
      "1stKung" => "Kung",
      "1stLet's Go" => "Let's Go",
      "1stLight" => "Light",
      "1stMikes" => "Mike's Song",
      "1stMockingbird" => "Fly Famous Mockingbird",
      "1stScent" => "Scent of a Mule",
      "1stStash" => "Stash",
      "1stSuzy" => "Suzy Greenberg",
      "1stTweezer" => "Tweezer",
      "1stWeekapaug" => "Weekapaug Groove",
      "1stYEM" => "You Enjoy Myself",
      "2001" => "Also Sprach Zarathustra",
      "2nd 20YL" => "Twenty Years Later",
      "2nd Bowie" => "David Bowie",
      "2nd CDT Reprise" => "Chalk Dust Torture Reprise",
      "2nd Ghost" => "Ghost",
      "2nd Harpua" => "Harpua",
      "2nd Hood" => "Harry Hood",
      "2nd HYHU" => "Hold Your Head Up",
      "2nd Light" => "Light",
      "2nd Martian Monster" => "Martian Monster",
      "2nd Terrapin" => "Terrapin",
      "2nd Weekapaug" => "Weekapaug Groove",
      "2nd YEM" => "You Enjoy Myself",
      "2nd Your Pet Cat" => "Your Pet Cat",
      "2ndASZ" => "Also Sprach Zarathustra",
      "2ndBathtub" => "Bathtub Gin",
      "2ndBowie" => "David Bowie",
      "2ndCities" => "Cities",
      "2ndCold As Ice" => "Cold as Ice",
      "2ndDWD" => "Down with Disease",
      "2ndHarpua" => "Harpua",
      "2ndHood" => "Harry Hood",
      "2ndHydrogen" => "I Am Hydrogen",
      "2ndHYHU" => "Hold Your Head Up",
      "2ndIcculus" => "Icculus",
      "2ndKung" => "Kung",
      "2ndLight" => "Light",
      "2ndMakisupa" => "Makisupa Policeman",
      "2ndMockingbird" => "Fly Famous Mockingbird",
      "2ndStash" => "Stash",
      "2ndSuzy" => "Suzy Greenberg",
      "2ndTweezer" => "Tweezer",
      "2ndWeekapaug" => "Weekapaug Groove",
      "2ndYEM" => "You Enjoy Myself",
      "3rd Harpua" => "Harpua",
      "3rd Tweezer" => "Tweezer",
      "3rdStash" => "Stash",
      "500 Miles" => "I'm Gonna Be (500 Miles)",
      "ACDCBag" => "AC/DC Bag",
      "All The Pain" => "All the Pain Through the Years",
      "Alumni" => "Alumni Blues",
      "Antelope" => "Run Like an Antelope",
      "ASIHTOS" => "A Song I Heard the Ocean Sing",
      "ASZ" => "Also Sprach Zarathustra",
      "ATrain" => "Take the 'A' Train",
      "Axilla II" => "Axilla (Part II)",
      "Bag" => "AC/DC Bag",
      "Bathtub" => "Bathtub Gin",
      "BBCFCM" => "Big Black Furry Creature from Mars",
      "BBCFM" => "Big Black Furry Creature from Mars",
      "BBFCFM Jam" => "Big Black Furry Creature from Mars",
      "BBFCFM" => "Big Black Furry Creature from Mars",
      "BBJ" => "Big Ball Jam",
      "BDTNL" => "Backwards Down the Number Line",
      "Big Black Furry Creature from Mars" => "Big Black Furry Creature from Mars",
      "Big Black Furry Creatures from Mars" => "Big Black Furry Creature from Mars",
      "Billie Jean Jam" => "Billie Jean",
      "Bittersweet" => "Bittersweet Motel",
      "BOAF" => "Birds of a Feather",
      "Boogie On" => "Boogie On Reggae Woman",
      "Boogie" => "Boogie On Reggae Woman",
      "BOTT" => "Back on the Train",
      "Bouncin" => "Bouncing Around the Room",
      "Bouncin'" => "Bouncing Around the Room",
      "Bowie" => "David Bowie",
      "Buried" => "Buried Alive",
      "C&P" => "Crosseyed and Painless",
      "Camel" => "Camel Walk",
      "Cantaloupe" => "Roll Like a Cantaloupe",
      "Caspian" => "Prince Caspian",
      "CDT" => "Chalk Dust Torture",
      "Chalk Dust" => "Chalk Dust Torture",
      "Chalkdust" => "Chalk Dust Torture",
      "Character" => "Character Zero",
      "Chracter" => "Character Zero",
      "Coil" => "The Squirming Coil",
      "Cold As Ice" => "Cold as Ice",
      "Crosseyed" => "Crosseyed and Painless",
      "CTB" => "Cars Trucks Buses",
      "Curtain With" => "The Curtain With",
      "Curtis Loew" => "The Ballad of Curtis Loew",
      "DDLJ" => "Digital Delay Loop Jam",
      "Dear Mrs Reagan" => "Dear Mrs. Reagan",
      "DEG" => "Dave's Energy Guide",
      "Dinner" => "Dinner and a Movie",
      "Divided" => "Divided Sky",
      "DWD Jam" => "Down with Disease",
      "DWD" => "Down with Disease",
      "DwD" => "Down with Disease",
      "DWDReprise" => "Down with Disease", # 1996-11-27 !! it's the second one
      "Feats" => "Feats Don't Fail Me Now",
      "Feel The Heat" => "Feel the Heat",
      "FEFY" => "Fast Enough for You",
      "Funky" => "Funky Bitch",
      "FYF" => "Fuck Your Face",
      "Gin" => "Bathtub Gin",
      "Golgi" => "Golgi Apparatus",
      "Great Gig in the Sky" => "The Great Gig in the Sky",
      "Great Gig" => "The Great Gig in the Sky",
      "GTBT" => "Good Times Bad Times",
      "Guelah" => "Guelah Papyrus",
      "GuyForget" => "Guy Forget",
      "HaHaHa" => "Ha Ha Ha",
      "Halfway" => "Halfway to the Moon",
      "Halley's" => "Halley's Comet",
      "Halleys" => "Halley's Comet",
      "Happy Birthday" => "Happy Birthday to You",
      "Heavy" => "Heavy Things",
      "Highway" => "Highway to Hell",
      "Hole" => "In a Hole",
      "Hood" => "Harry Hood",
      "Horse" => "The Horse",
      "Houses" => "Houses in Motion",
      "Hydrogen" => "I Am Hydrogen",
      "HYHU" => "Hold Your Head Up",
      "I AM Hydrogen" => "I Am Hydrogen",
      "IDK" => "I Didn't Know",
      "Its Ice" => "It's Ice",
      "JBG" => "Johnny B. Goode",
      "Jibboo" => "Gotta Jibboo",
      "JJLC" => "Jesus Just Left Chicago",
      "KDF" => "Kill Devil Falls",
      "LaGrange" => "La Grange",
      "Landlady" => "The Landlady",
      "Light Up" => "Light Up Or Leave Me Alone",
      "Limb" => "Limb By Limb",
      "Lizards" => "The Lizards",
      "Low Rider Jam" => "Low Rider",
      "LxL" => "Limb By Limb",
      "Makisupa" => "Makisupa Policeman",
      "Mango" => "The Mango Song",
      "McGrupp" => "McGrupp and the Watchful Hosemasters",
      "Melt" => "Split Open and Melt",
      "MFMF" => "My Friend, My Friend",
      "Mike's" => "Mike's Song",
      "Mikes" => "Mike's Song",
      "Mockingbird" => "Fly Famous Mockingbird",
      "Moma" => "The Moma Dance",
      "Monkey" => "Sleeping Monkey",
      "Moose" => "Moose the Mooche",
      "Mr P.C." => "Mr. P.C.",
      "MSO" => "My Sweet One",
      "MTG" => "Melt the Guns",
      "Mule" => "Scent of a Mule",
      "My Friend My Friend" => "My Friend, My Friend",
      "NMINML" => "No Men In No Man's Land",
      "Once" => "Once in a Lifetime",
      "P.Funk Medley" => "P-Funk Medley",
      "Peaches" => "Peaches en Regalia",
      "Punch You in the Eye" => "Punch You In the Eye",
      "PYITE" => "Punch You In the Eye",
      "Quinn" => "Quinn the Eskimo",
      "R&R" => "Rock and Roll",
      "Rhombus" => "Rhombus Narration",
      "Rock And Roll" => "Rock and Roll",
      "Rock" => "Rock and Roll",
      "Runaway" => "Runaway Jim",
      "Sally" => "Sneakin' Sally Through the Alley",
      "Sample" => "Sample in a Jar",
      "Scent" => "Scent of a Mule",
      "Scents" => "Scents and Subtle Sounds",
      "Seven" => "Seven Below",
      "SevenBelow" => "Seven Below",
      "Sevent Below" => "Seven Below",
      "Skin It" => "Skin It Back",
      "Slave" => "Slave to the Traffic Light",
      "SLI" => "Secret Language Instructions",
      "Sloth" => "The Sloth",
      "Smoke" => "Smoke on the Water",
      "Sneakin" => "Sneakin' Sally Through the Alley",
      "Sneakin' Sally" => "Sneakin' Sally Through the Alley",
      "Sneakin'" => "Sneakin' Sally Through the Alley",
      "SOAMelt" => "Split Open and Melt",
      "SOAMule" => "Scent of a Mule",
      "SOYF" => "Sunshine of Your Feeling",
      "STFTFP" => "Stealing Time From the Faulty Plan",
      "STTFTFP" => "Stealing Time From the Faulty Plan",
      "Subtle" => "Scents and Subtle Sounds",
      "Suzy" => "Suzy Greenberg",
      "Sweet Emotion Jam" => "Sweet Emotion",
      "The Way" => "The Way It Goes",
      "Theme from the Bottom" => "Theme From the Bottom",
      "Theme" => "Theme From the Bottom",
      "Timber Ho" => "Timber (Jerry The Mule)",
      "Timber" => "Timber (Jerry The Mule)",
      "TMWSIY" => "The Man Who Stepped Into Yesterday",
      "Tweeprise" => "Tweezer Reprise",
      "Tweezer Reprise Jam" => "Tweezer Reprise",
      "Tweezer Reprise" => "Ass Handed Reprise",
      "TweezerReprise" => "Tweezer Reprise",
      "Twqeezer" => "Tweezer",
      "TYL" => "Twenty Years Later",
      "Vibration of Life" => "The Vibration of Life",
      "Walls" => "Walls of the Cave",
      "Walrus" => "I Am the Walrus",
      "Wedge" => "The Wedge",
      "Weekapaug" => "Weekapaug Groove",
      "What's The Use" => "What's the Use?",
      "What's the Use" => "What's the Use?",
      "Whipping Post Jam" => "Whipping Post",
      "Whipping" => "Whipping Post",
      "Wolfman's" => "Wolfman's Brother",
      "Wolfmans" => "Wolfman's Brother",
      "WotC" => "Walls of the Cave",
      "WOTC" => "Walls of the Cave",
      "WTU?" => "What's the Use?",
      "YaMar" => "Ya Mar",
      "Yarmouth" => "Yarmouth Road",
      "YEM" => "You Enjoy Myself",
      "YPC" => "Your Pet Cat",
    }
  end
end
