namespace :shows do
  desc "Apply Bustout tags to all shows or specific date"
  task bustouts: :environment do
    date = ENV.fetch("DATE", nil)
    start_date = ENV.fetch("START_DATE", nil)

    rel = Show.includes(tracks: :songs_tracks).order(date: :asc)

    rel = rel.where(date:) if date.present?
    rel = rel.where('date >= ?', start_date) if start_date.present?

    pbar = ProgressBar.create(
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"
    )

    rel.each do |show|
      BustoutTagService.call(show)
      pbar.increment
    end

    pbar.finish
  end

  desc "Generate cover prompts, images, and zips for all shows or specific date"
  task art: :environment do
    date = ENV.fetch("DATE", nil)
    start_date = ENV.fetch("START_DATE", nil)

    rel = Show.includes(:tracks).order(date: :asc)

    if ENV.fetch("REDO", nil).present?
      redo_dates = File.readlines(Rails.root.join("lib/album_regen_list.txt")).map(&:strip)
      all_dates = redo_dates.dup
      redo_dates.each do |date|
        next unless show = Show.find_by(date: date)
        if show.cover_art_parent_show_id.present?
          all_dates << Show.find(show.cover_art_parent_show_id).date.to_s
          all_dates << Show.where(cover_art_parent_show_id: show.cover_art_parent_show_id).map(&:date).map(&:to_s)
        elsif (shows = Show.where(cover_art_parent_show_id: show.id)).any?
          all_dates << shows.map(&:date).map(&:to_s)
        end
      end
      rel = rel.where(date: all_dates.uniq.flatten)
    else
      rel = rel.where(date:) if date.present?
      rel = rel.where('date >= ?', start_date) if start_date.present?
    end

    pbar = ProgressBar.create \
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"
    InteractiveCoverArtService.call(rel, pbar)
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
