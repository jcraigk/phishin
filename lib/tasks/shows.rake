# frozen_string_literal: true
namespace :shows do
  desc 'Insert a track into a show at given position'
  task insert_track: :environment do
    opts = {
      date: ENV['DATE'],
      position: ENV['POSITION'],
      file: ENV['FILE'],
      title: ENV['TITLE'],
      song_id: ENV['SONG_ID'],
      set: ENV['SET'],
      is_sbd: ENV['SBD'].present?
    }

    TrackInsertionService.new(opts).call
    puts 'Track inserted'
  end

  desc 'Import a show'
  task import: :environment do
    require_relative '../show_importer'

    dates = Dir.entries(IMPORT_DIR).select do |entry|
      File.directory?(File.join(IMPORT_DIR, entry)) &&
        /\A\d{4}\-\d{2}\-\d{2}\z/.match?(entry)
    end

    next puts "No shows found in #{IMPORT_DIR}" unless dates.any?

    puts "#{dates.size} show folders found"
    dates.each do |date|
      puts '========================'
      puts " PROCESSING #{date}"
      puts '========================'
      ShowImporter::Cli.new(date)
    end
  end

  desc 'Find mis-labeled sets on tracks'
  task mislabeled_sets: :environment do
    show_list = []
    Show.order('date desc').find_each do |show|
      set_list = show.tracks.order('position').all.map(&:set)
      set_list.map! do |set|
        case set
        when 'S' then 0
        when 'E' then 4
        when 'E2' then 5
        when 'E3' then 6
        else set.to_i
        end
      end
      next unless set_list.present?
      set_list.each_with_index do |set, idx|
        if set_list[idx + 1] && set > set_list[idx + 1]
          show_list << show
          break
        end
      end
    end
    show_list.each do |show|
      puts "Check: #{show.date}"
    end
    puts 'No issues found' if show_list.empty?
  end
end
