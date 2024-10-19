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
    NUM_IMAGES = 3

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
      puts "💬 #{show.cover_art_prompt}"
      if rel.count > 1
        print "(P)rocess or (S)kip? "
        input = $stdin.gets.chomp.downcase
        if input != "p"
          pbar.increment
          puts "Skipping!"
          next
        end
      end

      # Prompt and cover art
      urls = []
      loop do
        # Use parent's cover art if part of a run
        if show.cover_art_parent_show_id.present?
          puts "Using parent cover art image..."
          show.cover_art.attach \
            Show.find(show.cover_art_parent_show_id).cover_art.blob
          break
        end

        txt = "Gen (i)mages, Gen (p)rompt, (U)RL, or custom prompt: "
        txt = "Use (1-#{NUM_IMAGES}), " + txt if urls.any?
        print txt
        input = $stdin.gets.chomp
        if input.length > 1
          puts "New prompt: 💬 #{input}"
          show.update!(cover_art_prompt: input)
          puts "Generating candidate images..."
          urls = []
          NUM_IMAGES.times do |i|
            image_url = CoverArtImageService.call(show, dry_run: true)
            puts "🏞 #{i + 1} #{image_url}"
            urls << image_url
          end
          next
        end
        case input.downcase
        when "i", "p"
          if input == "p"
            puts "Generating cover art prompt..."
            CoverArtPromptService.call(show)
            puts "💬 #{show.cover_art_prompt}"
          end
          puts "Generating candidate images..."
          urls = []
          NUM_IMAGES.times do |i|
            image_url = CoverArtImageService.call(show, dry_run: true)
            puts "🏞 #{i + 1} #{image_url}"
            urls << image_url
          end
          next
        when "u"
          print "URL: "
          url = $stdin.gets.chomp
          show.attach_cover_art_by_url(url)
          puts "🏞 #{show.cover_art_urls[:large]}"
          break
        when "1", "2", "3", "4"
          show.attach_cover_art_by_url(urls[input.to_i - 1])
          puts "🏞 #{show.cover_art_urls[:large]}"
          break
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
      if e.message.include?("blocked") # Dall-E rejected the prompt
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
