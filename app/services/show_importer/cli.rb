require "reline"

class ShowImporter::Cli
  attr_reader :orch

  def initialize(date, exclude_from_stats: false)
    puts "📅 Preparing #{date}"

    @orch = ShowImporter::Orchestrator.new(date, exclude_from_stats:)
    ShowImporter::TrackReplacer.new(date) && return if orch.show_found

    repl
  end

  def main_menu
    print_header
    orch.pp_list
    puts "\n\nTrack #, (i)nsert, (s)ave, e(x)it"
  end

  def print_header
    puts "\n🚌 #{orch.show.tour.name}"
    print_show_title
    print_notes
  end

  def print_show_title
    puts \
      "📍 #{orch.show.date} - #{orch.show.venue.name_on(orch.show.date)} " \
      "- #{orch.show.venue.location}\n"
  end

  def print_notes
    notes = orch.show.taper_notes&.encode! \
      "UTF-8", "binary", invalid: :replace, undef: :replace, replace: ""
    puts "📝 Taper Notes: #{pluralize(notes.split("\n").size, 'line')}" if notes.present?
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
    @help_str ||= "Combine (u)p, (S)ong, (F)ile, S(e)t, (T)itle, (D)elete, (B)ack"
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
  def process_pos(pos)
    while (line = Reline.readline("👉 ", false))
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
        main_menu
        break
      when "f"
        update_file_for_pos(pos)
        main_menu
        break
      when "e"
        if update_set_for_pos(pos)
          main_menu
        else
          invalid_input
        end
        break
      when "t"
        update_title_for_pos(pos)
        main_menu
        break
      when "d"
        puts "Deleting (#{pos}) #{orch.get_track(pos).title}"
        orch.delete(pos)
        main_menu
        break
      when "?"
        track = orch.get_track(pos)
        puts orch.track_display(track)
        puts help_str
      when "b"
        main_menu
        break
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

  def insert_new_track
    puts
    line = Reline.readline("Before track # (enter to cancel) 👉 ", true)
    pos = line.to_i
    return puts "Cancelled" unless pos.positive? && orch.get_track(pos)
    orch.insert_before(pos)
  end

  def update_song_for_pos(pos)
    line = Reline.readline("Song title 👉 ", true)
    matched = orch.fm.find_song(line, exact: true)
    if matched
      puts "Found \"#{matched.title}\". Adding Song."
      orch.get_track(pos).songs << matched
      puts "Adding #{matched.title} to pos #{pos}"
    end
    puts
  end

  def update_title_for_pos(pos)
    line = Reline.readline("Title 👉 ", true)
    orch.get_track(pos).title = line
    puts
  end

  VALID_SETS = %w[S 1 2 3 4 E E2 E3].freeze

  def update_set_for_pos(pos)
    line = Reline.readline("Set [S,1,2,3,4,E,E2,E3] 👉 ", true)
    return false unless VALID_SETS.include?(line)
    orch.get_track(pos).set = line
    puts
    true
  end

  def update_file_for_pos(pos) # rubocop:disable Metrics/MethodLength
    filenames = print_filenames
    while (line = Reline.readline("File 1-#{filenames.length} 👉 "))
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
    while (line = Reline.readline("👉 ", true))
      process(line)
      break if line.in?(%w[s x])
    end
  end

  def process(line)
    pos = line.to_i
    if pos.positive?
      return edit_for_pos(pos) if orch.get_track(pos)
      return invalid_input
    end
    return invalid_input unless line.in?(%w[i s x])
    menu_branch(line)
  end

  def menu_branch(line)
    case line
    when "i"
      insert_new_track
      main_menu
    when "s"
      orch.save
    end
  end

  def invalid_input
    main_menu
    puts "❌ Invalid input"
  end
end
