namespace :sets do

  #########################################################
  # This task queries the phish.net API and attempts to update Set information on each Track
  desc "Import Set info from pnet API"
  task :import => :environment do

    # require 'nokogiri'
    # require 'open-uri'
    require 'pnet'
    api_key = '448345A7B7688DDE43D0'

    pnet = PNet.new api_key
    
    # Show.where("show_date = ?", "1998-11-02").order(:show_date).all.each do |show|
    Show.order(:show_date).all.each do |show|
    # show = Show.find(393)
      setlist = Nokogiri::HTML(pnet.shows_setlists_get('showdate' => show.show_date)[0]["setlistdata"])
      set_titles = setlist.css('span.pnetsetlabel').map(&:content)
      set_titles.each do |title|
        abbrev_title = case title
          when "Set 1:" then "1"
          when "Set 2:" then "2"
          when "Set 3:" then "3"
          when "Set 4:" then "4"
          when "Encore:" then "E"
          when "Encore 2:" then "E2"
          when "Encore 3:" then "E3"
          when "Set e3:" then "E3"
          else "Unknown"
        end
        raise "Unknown set! (#{title})" if abbrev_title == "Unknown"
        song_titles = setlist.css('p.pnetset'+abbrev_title.downcase+' > a').map(&:content)
        song_titles.each do |song_title|
          tracks = Track.where("show_id = ?", show.id).kinda_matching(song_title).all
          tracks.each do |track|
            puts "Seeking track #{track.title} on #{show.id} -> #{show.show_date} :: #{title}"
            if track
              puts "Found"
              track.set = abbrev_title
              track.save
            else
              puts "NOT found!"
            end
          end
        end
      end
      
      # Find any Tracks that didn't get labled
      unlabeled_tracks = []
      show.tracks.each do |track|
        unlabeled_tracks << track.title if !track.set
      end
      # raise unlabeled_tracks.inspect
    end
  end

end
