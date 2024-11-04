namespace :shows do
  desc "Generate cover art"
  task art: :environment do
    date = ENV.fetch("DATE", nil)
    start_date = ENV.fetch("START_DATE", nil)

    rel = Show.where(cover_art_parent_show_id: nil).includes(:tracks).order(date: :asc)

    if ENV.fetch("REDO", nil).present?
      dates = File.readlines(Rails.root.join("lib/art_dates.txt")).map(&:strip)
      rel = rel.where(date: dates)
    else
      rel = rel.where(date:) if date.present?
      rel = rel.where('date >= ?', start_date) if start_date.present?
    end

    pbar = ProgressBar.create \
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"
    InteractiveCoverArtService.call(rel, pbar)
  end

  desc "Insert a track"
  task insert_track: :environment do
    TrackInserter.call \
      date: ENV["DATE"],
      position: ENV["POSITION"],
      file: ENV["FILE"],
      title: ENV["TITLE"],
      song_id: ENV["SONG_ID"],
      set: ENV["SET"],
      is_sbd: ENV["SBD"].present?,
      slug: ENV["SLUG"]
    puts "Track inserted"
  end

  desc "Import show(s) using PNet API and local MP3 audio files"
  task import: :environment do
    require "#{Rails.root}/app/services/show_importer"
    include ActionView::Helpers::TextHelper

    dates = Dir.entries(App.content_import_path).grep(/\d{4}\-\d{1,2}\-\d{1,2}\z/).sort
    next puts "❌ No shows found in #{App.content_import_path}" unless dates.any?

    puts "📂 #{pluralize(dates.size, 'folder')} found"
    dates.each { |date| ShowImporter::Cli.new(date) }
  end
end
