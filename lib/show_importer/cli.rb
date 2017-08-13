require 'readline'

module ShowImporter
  class Cli
    def initialize
      ARGV.each do |date|
        @si = ShowImporter.new(date)

        main_menu
        puts "\nTrack #, (f)ilenames, (l)ist, (i)nsert, (d)elete, (s)ave: "

        repl
      end
    end

    def main_menu
      puts "\n#{@si.show}\n\n"
      @si.pp_list
    end

    def print_filenames
      filenames = @si.fm.matches.keys

      filenames.each_with_index do |fn, i|
        puts format('%2d. %s', i + 1, fn)
      end
      filenames
    end

    def edit_for_pos(pos)
      help_str = 'Combine (u)p, Choose (s)ong, Choose (f)ile, Change s(e)t, Change (t)itle'
      puts @si.get_track(pos).to_s
      puts help_str

      while line = Readline.readline('#=> ', false)
        case line
        when 'u'
          puts "Combining up (#{pos}) #{@si.get_track(pos).title} into (#{pos - 1}) #{@si.get_track(pos - 1).title}"
          @si.combine_up(pos)
          break
        when 's'
          update_song_for_pos(pos)
        when 'f'
          update_file_for_pos(pos)
        when 'e'
          update_set_for_pos(pos)
        when 't'
          update_title_for_pos(pos)
        when '?'
          puts @si.get_track(pos).to_s
          puts help_str
        end
      end

      puts
    end

    def insert_new_track
      puts 'Before track #:'
      while line = Readline.readline('#=> ', true)
        @si.insert_before(line.to_i)
        break
      end
    end

    def delete_track
      puts 'Delete track #:'
      while line = Readline.readline('#=> ', true)
        @si.delete(line.to_i)
        break
      end
    end

    def update_song_for_pos(pos)
      puts 'Enter exact song title:'
      while line = Readline.readline('#=> ', true)
        matched = @si.fm.find_match(line, exact: true)
        if matched
          puts "Found \"#{match.title}\".  Adding Song."
          @si.get_track(pos).songs << match
        end
        break
      end

      puts
    end

    def update_title_for_pos(pos)
      puts 'Enter new title:'
      while line = Readline.readline('#=> ', true)
        @si.get_track(pos).title = line
        break
      end

      puts
    end

    def update_set_for_pos(pos)
      puts 'Enter new set abbrev [S,1,2,3,E,E2,E3]:'
      while line = Readline.readline('#=> ', true)
        @si.get_track(pos).set = line
        break
      end

      puts
    end

    def update_file_for_pos(pos)
      puts 'Choose a file:'
      filenames = print_filenames
      while line = Readline.readline("1-#{filenames.length} > ")
        choice = line.to_i
        next unless choice > 0
        new_filename = filenames[choice - 1]
        puts "Updating filename to '#{new_filename}'"
        @si.get_track(pos).filename = new_filename
        break
      end

      puts
    end

    private

    def repl
      while line = Readline.readline('> ', true)
        process(line)
      end
    end

    def process(line)
      pos = line.to_i
      return edit_for_pos(pos) if pos > 0

      menu_branch(line)
    end

    def menu_branch(line)
      case line
      when 'f'
        print_filenames
      when 'l'
        main_menu
      when 'i'
        insert_new_track
      when 'd'
        delete_track
      when 's'
        puts 'Saving...'
        @si.save
        exit
      end
    end
  end
end
