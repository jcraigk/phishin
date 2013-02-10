namespace :songs do
  task :populate_song_collections => :environment do 
    require 'open-uri'

    SONG_TITLES_URL = 'http://phish.net/song/'

    doc = Nokogiri::HTML(open(SONG_TITLES_URL))
    song_table = doc.at_css('table.tablesorter')

    song_table.css('td:first-child').each do |cell| 
      p "Adding Song for #{cell.text}"
      Song.create(:title => cell.text)
    end
  end

  task :match_songs => :environment do |t|
    def scrub_dir_path(dir)
      dir.gsub('\\', '')
    end

    def scrub_filename(filename)
      if filename =~ /mike/i
        "Mike's Song"
      else
        filename
          .gsub('.mp3', '')
          .gsub(/^II?/, '')
          .gsub('_', ' ')
      end
    end

    dir_path = scrub_dir_path ENV['dir']

    entries = Dir.entries(dir_path).reject{ |e| e == '.' || e == '..' }
    entries.each do |filename|
      sfilename = scrub_filename(filename)
      found = Song.kinda_matching(sfilename).first

      if found
        puts "FOUND:\n\t#{filename}\n\t#{found.title}"
      else
        puts "ERROR:\n#{filename} not found"
      end
    end
  end
end
