# frozen_string_literal: true

# .where(date: Date.new(2023, 1, 1)..Date.new(2024, 12, 31))

namespace :shows do
  desc "Generate cover art prompts"
  task generate_cover_art: :environment do
    rel = Show.includes(:tracks)
              .where(date: '2017-08-06')
              .order(date: :asc)
    pbar = ProgressBar.create(
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"
    )

    rel.each do |show|
      pbar.increment
      # next if show.cover_art.attached?

      CoverArtPromptService.new(show).call
      CoverArtImageService.new(show).call

      # Apply cover art to mp3 files
      show.tracks.each do |track|
        track.apply_id3_tags
      end
    end

    pbar.finish
  end

  desc 'Insert a track into a show at given position'
  task insert_track: :environment do
    opts = {
      date: ENV['DATE'],
      position: ENV['POSITION'],
      file: ENV['FILE'],
      title: ENV['TITLE'],
      song_id: ENV['SONG_ID'],
      set: ENV['SET'],
      is_sbd: ENV['SBD'].present?,
      slug: ENV['SLUG']
    }

    TrackInserter.new(opts).call
    puts 'Track inserted'
  end

  desc 'Import a show'
  task import: :environment do
    require "#{Rails.root}/app/services/show_importer"
    include ActionView::Helpers::TextHelper

    dates = Dir.entries(App.content_import_path).grep(/\d{4}\-\d{1,2}\-\d{1,2}\z/).sort
    next puts "❌ No shows found in #{App.content_import_path}" unless dates.any?

    puts "🔎 #{pluralize(dates.size, 'folder')} found"
    dates.each { |date| ShowImporter::Cli.new(date) }
  end
end
