# frozen_string_literal: true
require 'readline'

class ShowImporter::Cli
  attr_reader :orch

  def initialize(date)
    @orch = ShowImporter::Orchestrator.new(date)

    if orch.show_found
      ShowImporter::TrackReplacer.new(date)
    else
      main_menu
      repl
    end
  end

  def main_menu
    puts "\n#{orch.show.date} - #{orch.show.venue.name} - #{orch.show.venue.location}\n\n"
    orch.pp_list
    puts "\n\nTrack #, (f)ilenames, (l)ist, (i)nsert, (d)elete, (s)ave, e(x)it: "
  end

  def print_filenames
    filenames = orch.fm.matches.keys

    filenames.each_with_index do |fn, i|
      puts format('%2<idx>d. %<fn>s', idx: i + 1, fn: fn)
    end
    filenames
  end

  def edit_for_pos(pos)
    puts orch.get_track(pos).to_s
    puts help_str

    process_pos(pos)

    puts
  end

  def help_str
    @help_str ||= 'Combine (u)p, (S)ong, (F)ile, S(e)t, (T)itle, (M)ain menu'
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
  def process_pos(pos)
    while (line = Readline.readline('#=> ', false))
      case line.downcase
      when 'u'
        puts(
          "Combining up (#{pos}) #{orch.get_track(pos).title} into " \
          "(#{pos - 1}) #{orch.get_track(pos - 1).title}"
        )
        orch.combine_up(pos)
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
        puts orch.get_track(pos).to_s
        puts help_str
      when 'm'
        main_menu
        break
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

  def insert_new_track
    puts 'Before track #:'
    while (line = Readline.readline('#=> ', true))
      orch.insert_before(line.to_i)
      break
    end
  end

  def delete_track
    puts 'Delete track #:'
    while (line = Readline.readline('#=> ', true))
      orch.delete(line.to_i)
      break
    end
  end

  def update_song_for_pos(pos) # rubocop:disable Metrics/MethodLength
    puts 'Enter exact song title:'
    while (line = Readline.readline('#=> ', true))
      matched = orch.fm.find_match(line, exact: true)
      if matched
        puts "Found \"#{matched.title}\".  Adding Song."
        orch.get_track(pos).songs << matched
        puts "Adding #{matched.title} to pos #{pos}"
      end
      break
    end

    puts
  end

  def update_title_for_pos(pos)
    puts 'Enter new title:'
    while (line = Readline.readline('#=> ', true))
      orch.get_track(pos).title = line
      break
    end

    puts
  end

  def update_set_for_pos(pos)
    puts 'Enter new set abbrev [S,1,2,3,4,E,E2,E3]:'
    while (line = Readline.readline('#=> ', true))
      orch.get_track(pos).set = line
      break
    end

    puts
  end

  def update_file_for_pos(pos) # rubocop:disable Metrics/MethodLength
    puts 'Choose a file:'
    filenames = print_filenames
    while (line = Readline.readline("1-#{filenames.length} > "))
      choice = line.to_i
      next unless choice.positive?
      new_filename = filenames[choice - 1]
      puts "Updating filename to '#{new_filename}'"
      orch.get_track(pos).filename = new_filename
      break
    end

    puts
  end

  private

  def repl
    while (line = Readline.readline('> ', true))
      process(line)
    end
  end

  def process(line)
    pos = line.to_i
    return edit_for_pos(pos) if pos.positive?
    menu_branch(line)
  end

  def menu_branch(line) # rubocop:disable Metrics/MethodLength
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
      orch.save
    when 'x'
      exit
    end
  end
end
