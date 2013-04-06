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
      @fm    = FilenameMatcher.new date

      @show = Show.where(:date => date).first || \
              Show.new(:location => @show_info.location, :date => date)

      @songs = []
      populate_songs
    end

    def pp_list
      @songs.sort{ |a,b| a.pos <=> b.pos }.each do |song|
        puts song
      end
    end

    def combine_up(pos)
      assimilating = get_song(pos)
      receiving = get_song(pos - 1)

      return if assimilating.nil? || receiving.nil?

      receiving.merge_track(assimilating)
      @songs.delete assimilating

      @songs.each { |song| song.decr_pos if song.pos > pos }
    end

    def insert_before(pos)
      @songs.each { |song| song.incr_pos if song.pos >= pos }
      @songs.insert pos, TrackProxy.new(pos)
    end

    def delete(pos)
      @songs.delete_if { |song| song.pos == pos }
      @songs.each { |song| song.decr_pos if song.pos > pos }
    end

    def get_song(pos)
      @songs.find{|s| s.pos == pos}
    end

    def save
      @show.save
      @songs.each do |s|
        if s.valid?
          s.show = @show
          s.audio_file = File.new("#{@fm.s_dir}/#{s.filename}")
          s.save
        end
      end
    end

    private

    def populate_songs
      matches = @fm.matches.dup
      @show_info.songs.each do |pos, song|
        fn_match = matches.find{ |k,v| !v.nil? && v.title == song }
        if fn_match
          @songs << TrackProxy.new(pos, song, fn_match[0], fn_match[1])
          matches.delete(fn_match[0])
        else
          @songs << TrackProxy.new(pos, song)
        end
      end
    end
  end


  class TrackProxy
    attr_accessor :filename

    def initialize(pos=nil, title=nil, filename=nil, song=nil)
      @_track = ::Track.new(:position => pos, :title => title)

      song ||= ::Song.find_by_title(title)

      @_track.songs << song unless song.nil?

      @filename = filename
    end

    def valid?
      !@filename.nil? && !@_track.title.nil? && !@_track.position.nil? && !@_track.songs.empty?
    end

    def to_s
      (!valid? ? '* ' : '  ') + 
      ("%2d.) %-30.30s     %-30.30s     " % [pos, @_track.title, @filename]) + 
      @_track.songs.map{ |sc| "SC: %-3d %-20.20s" % [sc.id, sc.title] }.join('   ')
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

        puts "\nPick a position to edit, Toggle S(b)D, Show (f)ilenames, Show song (l)ist, (i)nsert new, (d)elete song, (s)ave: "
        while line = Readline.readline('#bflids> ', true)
          pos = line.to_i
          if pos > 0
            edit_for_pos(pos)
          elsif line == 'b'
            toggle_sbd
            puts "Is SBD: " + (@si.show.sbd ? 'YES' : 'NO')
          elsif line == 'f'
            print_filenames
          elsif line == 'l'
            main_menu
          elsif line == 'i'
            insert_new_song
          elsif line == 'd'
            delete_song
          elsif line == 's'
            puts "Saving..."
            @si.save
            break
          end
        end
      end
    end

    def main_menu
      puts "\n#{@si.show} #{' ::SBD::' if @si.show.sbd}\n\n"
      @si.pp_list
    end

    def print_filenames
      filenames = @si.fm.matches.keys

      filenames.each_with_index do |fn, i| 
        puts "%2d.) %s" % [i + 1, fn]
      end
      filenames
    end

    def edit_for_pos(pos)
      help_str = "Combine (u)p, Choose (s)ong collection, Choose (f)ile, Change (t)itle"
      puts "#{@si.get_song(pos)}"
      puts help_str

      while line = Readline.readline('usft?> ', false)

        if line == 'u'
          puts "Combining up (#{pos}) #{@si.get_song(pos).title} into (#{pos - 1}) #{@si.get_song(pos - 1).title}"
          @si.combine_up(pos)
          break
        elsif line == 's'
          update_sc_for_pos(pos)
        elsif line == 'f'
          update_file_for_pos(pos)
        elsif line == 't'
          update_title_for_pos(pos)
        elsif line == '?'
          puts "#{@si.get_song(pos)}"
          puts help_str
        end

      end
      puts
    end

    def insert_new_song
      puts "Before song #:"
      while line = Readline.readline('> ', true)
        @si.insert_before(line.to_i)
        break
      end
    end

    def delete_song
      puts "Delete song #:"
      while line = Readline.readline('> ', true)
        @si.delete(line.to_i)
        break
      end
    end

    def update_sc_for_pos(pos)
      puts "Enter exact song title:"
      while line = Readline.readline('?> ', true)
        if match = @si.fm.find_match(line, :exact => true)
          puts "Found \"#{match.title}\".  Adding Song."
          @si.get_song(pos).songs << match
        end
        break
      end
      puts
    end

    def update_title_for_pos(pos)
      puts "Enter new title:"
      while line = Readline.readline('> ', true)
        @si.get_song(pos).title = line
        break
      end
      puts
    end

    def toggle_sbd
      @si.show.sbd = !@si.show.sbd
    end

    def update_file_for_pos(pos)
      puts "Choose a file:"
      filenames = print_filenames

      while line = Readline.readline("1-#{filenames.length} > ")
        choice = line.to_i
        if choice > 0
          new_filename = filenames[choice - 1]
          puts "Updating filename to '#{new_filename}'"
          @si.get_song(pos).filename = new_filename
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