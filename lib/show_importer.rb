require_relative '../config/environment'
require_relative 'show_info'
require_relative 'filename_matcher'

module ShowImporter
  
  class ShowImporter
    attr_reader :show, :fm, :songs

    def initialize(date)
      
      puts "Fetching show info..."
      @show_info = ShowInfo.new date
      
      puts "Analyzing filenames..."
      @fm = FilenameMatcher.new date

      if @show = Show.where(:date => date).first
        puts "Show for #{date} already imported!" and exit if !@show.missing
      else
        @show = Show.new(:date => date)
      end
      
      puts "Finding venue..."
      @venue = Venue.where('past_names LIKE ? AND city = ?', "%#{@show_info.venue_name}%", @show_info.venue_city).first unless @venue = Venue.where(name: @show_info.venue_name, city: @show_info.venue_city).first
      @show.venue = @venue if @venue

      @tracks = []
      populate_tracks
    end

    def pp_list
      @tracks.sort{ |a,b| a.pos <=> b.pos }.each do |track|
        puts track
      end
    end

    def combine_up(pos)
      assimilating = get_track(pos)
      receiving = get_track(pos - 1)

      return if assimilating.nil? || receiving.nil?

      receiving.merge_track(assimilating)
      @tracks.delete assimilating

      @tracks.each { |track| track.decr_pos if track.pos > pos }
    end

    def insert_before(pos)
      @tracks.each { |track| track.incr_pos if track.pos >= pos }
      @tracks.insert pos, TrackProxy.new(pos)
    end

    def delete(pos)
      @tracks.delete_if { |track| track.pos == pos }
      @tracks.each { |track| track.decr_pos if track.pos > pos }
    end

    def get_track(pos)
      @tracks.find{|s| s.pos == pos}
    end

    def save
      @show.save
      duration = 0
      @tracks.each do |t|
        if t.valid?
          t.show = @show
          t.audio_file = File.new("#{@fm.s_dir}/#{t.filename}")
          t.save
          t.save_default_id3_tags
          # duration += t.duration
        end
      end
      # @show.update_attributes(duration: duration)
    end

    private

    def populate_tracks
      matches = @fm.matches.dup
      @show_info.songs.each do |pos, song_title|
        fn_match = matches.find{ |k,v| !v.nil? && v.title == song_title }
        if fn_match
          @tracks << TrackProxy.new(pos, song_title, fn_match[0], fn_match[1])
          matches.delete(fn_match[0])
        else
          @tracks << TrackProxy.new(pos, song_title)
        end
      end
    end
  end


  class TrackProxy
    attr_accessor :filename

    def initialize(pos=nil, title=nil, filename=nil, song=nil)
      @_track = Track.new(position: pos, title: title, set: get_set_from_filename(filename), slug: generic_slug(title))
      song ||= Song.find_by_title(title)
      @_track.songs << song unless song.nil?
      @filename = filename
    end
    
    def generic_slug(title)
      title ? title.downcase.gsub(/'/, '').gsub(/[^a-z0-9]/, ' ').strip.gsub(/\s+/, ' ').gsub(/\s/, '-') : ''
    end

    def get_set_from_filename(filename)
      if filename.nil?
        "1"
      elsif filename[0...6] == '(Check)'
        "S"
      elsif filename[0..3] == 'II-e'
        "E"
      elsif filename[0..2] == 'III'
        "3"
      elsif filename[0..1] == 'II'
        "2"
      else
        "1"
      end
    end

    def valid?
      !@filename.nil? && !@_track.title.nil? && !@_track.position.nil? \
        && !@_track.songs.empty? && !@_track.set.nil?
    end

    def to_s
      (!valid? ? '* ' : '  ') + 
      ("%2d. [%1s] %-30.30s     %-30.30s     " % [pos, @_track.set, @_track.title, @filename]) + 
      @_track.songs.map{ |song| "(%-3d) %-20.20s" % [song.id, song.title] }.join('   ')
    end

    def pos
      @_track.position
    end

    def decr_pos
      @_track.position -= 1
    end

    def incr_pos
      @_track.position += 1
    end

    def merge_track(track)
      @_track.title += " > #{track.title}"
      @_track.songs << track.songs.reject{ |s| @_track.songs.include?(s) }
      @filename = track.filename if @filename.nil? && !track.filename.nil?
    end

    def method_missing(method, *args, &block)
      @_track.send(method, *args)
    end
  end


  class Cli
    def initialize
      require 'readline'
      ARGV.each do |date|
        @si = ShowImporter.new(date)
        main_menu
        puts "\nTrack #, (f)ilenames, (l)ist, (i)nsert, (d)elete, (s)ave: "
        while line = Readline.readline('> ', true)
          pos = line.to_i
          if pos > 0
            edit_for_pos(pos)
          elsif line == 'f'
            print_filenames
          elsif line == 'l'
            main_menu
          elsif line == 'i'
            insert_new_track
          elsif line == 'd'
            delete_track
          elsif line == 's'
            puts "Saving..."
            @si.save
            break
          end
        end
      end
    end

    def main_menu
      puts "\n#{@si.show}\n\n"
      @si.pp_list
    end

    def print_filenames
      filenames = @si.fm.matches.keys

      filenames.each_with_index do |fn, i| 
        puts "%2d. %s" % [i + 1, fn]
      end
      filenames
    end

    def edit_for_pos(pos)
      help_str = "Combine (u)p, Choose (s)ong, Choose (f)ile, Change s(e)t, Change (t)itle"
      puts "#{@si.get_track(pos)}"
      puts help_str

      while line = Readline.readline('#=> ', false)

        if line == 'u'
          puts "Combining up (#{pos}) #{@si.get_track(pos).title} into (#{pos - 1}) #{@si.get_track(pos - 1).title}"
          @si.combine_up(pos)
          break
        elsif line == 's'
          update_song_for_pos(pos)
        elsif line == 'f'
          update_file_for_pos(pos)
        elsif line == 'e'
          update_set_for_pos(pos)
        elsif line == 't'
          update_title_for_pos(pos)
        elsif line == '?'
          puts "#{@si.get_track(pos)}"
          puts help_str
        end

      end
      puts
    end

    def insert_new_track
      puts "Before track #:"
      while line = Readline.readline('#=> ', true)
        @si.insert_before(line.to_i)
        break
      end
    end

    def delete_track
      puts "Delete track #:"
      while line = Readline.readline('#=> ', true)
        @si.delete(line.to_i)
        break
      end
    end

    def update_song_for_pos(pos)
      puts "Enter exact song title:"
      while line = Readline.readline('#=> ', true)
        if match = @si.fm.find_match(line, :exact => true)
          puts "Found \"#{match.title}\".  Adding Song."
          @si.get_track(pos).songs << match
        end
        break
      end
      puts
    end

    def update_title_for_pos(pos)
      puts "Enter new title:"
      while line = Readline.readline('#=> ', true)
        @si.get_track(pos).title = line
        break
      end
      puts
    end
    
    def update_set_for_pos(pos)
      puts "Enter new set abbrev [S,1,2,3,E,E2,E3]:"
      while line = Readline.readline('#=> ', true)
        @si.get_track(pos).set = line
        break
      end
      puts
    end

    def update_file_for_pos(pos)
      puts "Choose a file:"
      filenames = print_filenames
      while line = Readline.readline("1-#{filenames.length} > ")
        choice = line.to_i
        if choice > 0
          new_filename = filenames[choice - 1]
          puts "Updating filename to '#{new_filename}'"
          @si.get_track(pos).filename = new_filename
          break
        end
      end
      puts
    end
  end
end



if __FILE__ == $0
  if ARGV.length < 1
    puts "Need date"
  else
    ShowImporter::Cli.new
  end
end