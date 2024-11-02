namespace :shows do
  desc "Generate cover prompts, images, and zips for all shows or specific date"
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

  desc "Apply ID3 tags and purge Cloudflare cache"
  task id3_tags: :environment do
    start_id = ENV.fetch("START_ID", nil)

    rel = Show.includes(:tracks)
    rel = rel.where('id >= ?', start_id) if start_id.present?

    pbar = ProgressBar.create \
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"

    rel.find_each do |show|
      show.tracks.each do |track|
        track.apply_id3_tags
        CloudflareCachePurgeService.call(track.mp3_url)
      end
      puts "🎉 ID3 tags applied to #{show.date} / #{show.id}"
      pbar.increment
    end

    pbar.finish
  end

  desc "Insert a track into a show at given position"
  task insert_track: :environment do
    opts = {
      date: ENV["DATE"],
      position: ENV["POSITION"],
      file: ENV["FILE"],
      title: ENV["TITLE"],
      song_id: ENV["SONG_ID"],
      set: ENV["SET"],
      is_sbd: ENV["SBD"].present?,
      slug: ENV["SLUG"]
    }

    TrackInserter.new(opts).call
    puts "Track inserted"
  end

  desc "Import a show"
  task import: :environment do
    require "#{Rails.root}/app/services/show_importer"
    include ActionView::Helpers::TextHelper

    dates = Dir.entries(App.content_import_path).grep(/\d{4}\-\d{1,2}\-\d{1,2}\z/).sort
    next puts "❌ No shows found in #{App.content_import_path}" unless dates.any?

    puts "🔎 #{pluralize(dates.size, 'folder')} found"
    dates.each { |date| ShowImporter::Cli.new(date) }
  end
end
