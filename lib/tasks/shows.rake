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

    TrackInserter.new(opts).call
    puts 'Track inserted'
  end

  desc 'Import a show'
  task import: :environment do
    require "#{Rails.root}/app/services/show_importer/show_importer"

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

  desc 'Find shows with a single set'
  task single_set: :environment do
    relation = Show.unscoped.includes(:tracks).order(date: :asc)
    pbar = ProgressBar.create(
      total: relation.size,
      format: '%a %B %c/%C %p%% %E'
    )

    dates = {}
    relation.find_each do |show|
      sets = show.tracks.map(&:set).uniq
      dates[show.date.to_s(:db)] = sets.first if sets.size < 2
      pbar.increment
    end

    pbar.finish
    puts "Found #{dates.size} shows"
    dates.each do |k, v|
      puts "#{k} #{v}"
    end
  end
end
