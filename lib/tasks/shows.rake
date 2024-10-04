namespace :shows do
  desc "Generate cover prompts, images, and zips for all shows or specific date"
  task generate_albums: :environment do
    date = ENV.fetch("DATE", nil)
    force = ENV.fetch("FORCE", nil).present?

    rel = Show.includes(:tracks)
              .order(date: :asc)
              .where('date >= ?', Date.parse('1991-02-21'))
    rel = rel.where(date:) if date.present?
    pbar = ProgressBar.create(
      total: rel.count,
      format: "%a %B %c/%C %p%% %E"
    )

    rel.each do |show|
      pbar.increment

      if force || (show.cover_art_prompt.blank? && show.cover_art_parent_show_id.blank?)
        CoverArtPromptService.call(show)
        if show.cover_art_parent_show_id.present?
          puts "PROMPT (DEFER): #{show.cover_art_parent_show_id}"
        else
          puts "PROMPT (NEW): #{show.cover_art_prompt}"
        end
      end

      if force || !show.cover_art.attached?
        CoverArtImageService.call(show)
        # sleep 1 # for Dall-E API rate limiting
        puts Rails.application.routes.url_helpers.rails_blob_url(show.cover_art)
      end

      if force || !show.album_cover.attached?
        AlbumCoverService.call(show)
        puts Rails.application.routes.url_helpers.rails_blob_url(show.album_cover)

        # Apply cover art to mp3 files
        show.tracks.each do |track|
          track.apply_id3_tags
        end
      end

      if force || !show.album_zip.attached?
        AlbumZipJob.new.perform(show.id)
      end

      puts show.url
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
