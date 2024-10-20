require "readline"

class ShowImporter::Cli
  attr_reader :orch

  def initialize(date)
    puts "Preparing #{date}"

    @orch = ShowImporter::Orchestrator.new(date)
    ShowImporter::TrackReplacer.new(date) && return if orch.show_found

    repl
  end

  def main_menu
    print_header
    orch.pp_list
    puts "\n\nTrack #, (f)ilenames, (l)ist, (i)nsert, (d)elete, (s)ave, e(x)it: "
  end

  def print_header
    puts "\n🚌 #{orch.show.tour.name}"
    print_show_title
    print_notes
  end

  def print_show_title
    puts \
      "🏛️ #{orch.show.date} - #{orch.show.venue.name_on(orch.show.date)} " \
      "- #{orch.show.venue.location}\n"
  end

  def print_notes
    notes = orch.show.taper_notes&.encode! \
      "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ""
    puts "📒 Taper Notes: #{pluralize(notes.split("\n").size, 'line')}" if notes.present?
    puts "\n"
  end

  def print_filenames
    filenames = orch.fm.matches.keys

    filenames.each_with_index do |fn, i|
      puts format("%2<idx>d. %<fn>s", idx: i + 1, fn:)
    end
    filenames
  end

  def edit_for_pos(position)
    track = orch.get_track(position)
    puts orch.track_display(track)
    puts help_str

    process_pos(position)

    puts
  end

  def help_str
    @help_str ||= "Combine (u)p, (S)ong, (F)ile, S(e)t, (T)itle, (L)ist"
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
  def process_pos(pos)
    while (line = Readline.readline("➡ ", false))
      case line.downcase
      when "u"
        puts(
          "Combining up (#{pos}) #{orch.get_track(pos).title} into " \
          "(#{pos - 1}) #{orch.get_track(pos - 1).title}"
        )
        orch.combine_up(pos)
        main_menu
        break
      when "s"
        update_song_for_pos(pos)
      when "f"
        update_file_for_pos(pos)
      when "e"
        update_set_for_pos(pos)
      when "t"
        update_title_for_pos(pos)
      when "?"
        track = orch.get_track(pos)
        puts orch.track_display(track)
        puts help_str
      when "l"
        main_menu
        break
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

  def insert_new_track
    puts "Before track #:"
    line = Readline.readline("➡ ", true)
    orch.insert_before(line.to_i)
  end

  def delete_track
    puts "Delete track #:"
    line = Readline.readline("➡ ", true)
    orch.delete(line.to_i)
  end

  def update_song_for_pos(pos)
    puts "Enter exact song title:"
    line = Readline.readline("➡ ", true)
    matched = orch.fm.find_song(line, exact: true)
    if matched
      puts "Found \"#{matched.title}\". Adding Song."
      orch.get_track(pos).songs << matched
      puts "Adding #{matched.title} to pos #{pos}"
    end
    puts
  end

  def update_title_for_pos(pos)
    puts "Enter new title:"
    line = Readline.readline("➡ ", true)
    orch.get_track(pos).title = line
    puts
  end

  def update_set_for_pos(pos)
    puts "Enter new set abbrev [S,1,2,3,4,E,E2,E3]:"
    line = Readline.readline("➡ ", true)
    orch.get_track(pos).set = line
    puts
  end

  def update_file_for_pos(pos) # rubocop:disable Metrics/MethodLength
    puts "Choose a file:"
    filenames = print_filenames
    while (line = Readline.readline("1-#{filenames.length} ➡ "))
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
    main_menu
    while (line = Readline.readline("↪ ", true))
      process(line)
      break if line.in?(%w[s x])
    end
  end

  def process(line)
    pos = line.to_i
    return edit_for_pos(pos) if pos.positive?
    menu_branch(line)
  end

  def menu_branch(line) # rubocop:disable Metrics/MethodLength
    case line
    when "d"
      delete_track
      main_menu
    when "f"
      print_filenames
    when "i"
      insert_new_track
      main_menu
    when "l"
      main_menu
    when "s"
      orch.save
    end
  end
end
