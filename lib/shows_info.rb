require 'open-uri'
require_relative 'pnet'

class ShowsInfo
  SHOW_LIST_URL = 'https://spreadsheets.google.com/spreadsheet/pub?key=0AjeIQ6qQvexzcDhXS2twUC1US3BPMVZuUWdjZmY2RVE&gid=5'
  PNET_API_KEY = '448345A7B7688DDE43D0'
  IDX = {
    date: 1, 
    sbd: 2, 
    venue: 4,
    city: 5,
    state: 6,
    link: 7
  }

  def initialize
    @pnet = PNet.new PNET_API_KEY
  end

  def get_songs(url)
    doc         = Nokogiri::HTML(open(url))
    songTable   = doc.at_css('table#tblMain')
    firstRowIdx = 7

    rows = doc.css('tr')[firstRowIdx..-1]

    rows.each do |row|
      fields = row.children
      unless fields[IDX[:date]].content.blank? || fields[IDX[:link]].content.blank?
        show_date = fields[IDX[:date]].content
        puts "#{show_date} -- #{fields[IDX[:venue]].content} - #{fields[IDX[:city]].content}, #{fields[IDX[:state]].content}"

        setlist = @pnet.shows_setlists_get('showdate' => format_date(show_date))[0];
        songs = Nokogiri::HTML(setlist["setlistdata"]).css('p.pnetset > a').map(&:content)

        # Sometimes songs will be empty, returned from phish.net API.  Ex. 1993-08-21
        songs.each_with_index do |song, i|
          puts "#{i + 1}. #{song}"
        end
      end
    end
  end

  protected

  def format_date(date)
    month, day, year = date.split('/')
    "%d-%02d-%02d" % [year, month, day]
  end
end