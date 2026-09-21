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
      rel = rel.where("date >= ?", start_date) if start_date.present?
    end

    InteractiveCoverArtService.call(rel, image_model: ENV.fetch("MODEL", nil).presence)
  end

  desc "Insert a track"
  task insert_track: :environment do
    TrackInserter.new(
      date: ENV["DATE"],
      position: ENV["POSITION"],
      file: ENV["FILE"],
      title: ENV["TITLE"],
      song_id: ENV["SONG_ID"],
      set: ENV["SET"],
      is_sbd: ENV["SBD"].present?,
      slug: ENV["SLUG"]
    ).call
    puts "Track inserted"
  end

  desc "Import show(s) using PNet API and local MP3 audio files (prefer the web admin at /admin)"
  task import: :environment do
    require "#{Rails.root}/app/services/show_importer"
    include ActionView::Helpers::TextHelper

    puts "ℹ️  The web admin panel (/admin) is the preferred way to import shows; this CLI remains for batch use."

    dates = Dir.entries(App.content_import_path).grep(/\d{4}\-\d{1,2}\-\d{1,2}\z/).sort
    next puts "❌ No shows found in #{App.content_import_path}" unless dates.any?

    exclude_from_stats = ENV["EXCLUDE_FROM_STATS"].present?

    puts "🚫 EXCLUDE_FROM_STATS set" if exclude_from_stats
    puts "📂 #{pluralize(dates.size, 'folder')} found"
    dates.each do |date|
      ShowImporter::Cli.new(date, exclude_from_stats:)
    rescue ShowImporter::ShowInfo::NotFoundError => e
      puts "❌ #{e.message}"
    end
  end
end
