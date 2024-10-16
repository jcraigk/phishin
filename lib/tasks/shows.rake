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
  task generate_albums: :environment do
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

    pbar = ProgressBar.create(
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"
    )

    rel.each do |show|
      puts "🏟 #{show.url} / #{show.venue_name} / #{show.venue.location}"
      print "(R)egenerate or (S)kip? "
      input = $stdin.gets.chomp.downcase
      if input != "r"
        pbar.increment
        puts "Skipping!"
        next
      else
        puts "💬 #{show.cover_art_prompt}"
      end

      # Prompt and cover art
      loop do
        puts "Generating cover art image..."
        CoverArtImageService.call(show)
        puts "🏞 #{App.base_url}/blob/#{show.cover_art.blob.key}"
        print "(C)onfirm, (R)egenerate, (N)ew prompt, or C(u)stomize prompt? "
        input = $stdin.gets.chomp.downcase
        case input
        when "r"
          next
        when "n"
          puts "Generating cover art prompt..."
          CoverArtPromptService.call(show)
          puts "💬 #{show.cover_art_prompt}"
          next
        when "u"
          print "Custom prompt (or blank to use existing): "
          prompt = $stdin.gets.chomp
          if prompt.present?
            puts "New prompt: 💬 #{prompt}"
            show.update!(cover_art_prompt: prompt)
          else
            puts "Using existing prompt"
          end
          next
        else
          break
        end
      end

      # Album cover
      AlbumCoverService.call(show)
      puts "🌌 #{show.album_cover_url}"
      show.tracks.each(&:apply_id3_tags)

      puts show.url
      pbar.increment
    rescue StandardError => e
      if e.message.include?("blocked") # Dall-E regected the prompt
        puts "RETRYING #{show.date}"
        retry
      else
        binding.irb
      end
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
