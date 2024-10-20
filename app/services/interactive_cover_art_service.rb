class InteractiveCoverArtService < BaseService
  extend Dry::Initializer

  param :relation

  attr_accessor :pbar

  NUM_IMAGES = 3

  def call
    if relation.count > 1
      @pbar = ProgressBar.create \
        total: relation.count,
        format: "%a %B %c/%C %p%% %E"
    end

    interactive_cli
  end

  def interactive_cli
    relation.each do |show| # rubocop:disable Metrics/BlockLength
      puts "🏟 #{show.url} - #{show.venue_name} - #{show.venue.location}"
      if show.cover_art_parent_show_id.present?
        puts "🔗 Parent: #{Show.find(show.cover_art_parent_show_id).url}"
      else
        if show.cover_art_prompt.blank?
          puts "Generating cover art prompt..."
          CoverArtPromptService.call(show)
        end
        puts "💬 #{show.cover_art_prompt}"
      end

      if relation.count > 1
        print "(P)rocess or (S)kip? "
        input = $stdin.gets.chomp.downcase
        if input != "p"
          pbar.increment if pbar
          puts "Skipping!"
          next
        end
      end

      # Prompt and cover art
      urls = []
      loop do # rubocop:disable Metrics/BlockLength
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
          # puts "🏞 #{show.cover_art_urls[:large]}"
          break
        else
          break
        end
      end

      # Album cover
      AlbumCoverService.call(show)
      # puts "🌌 #{show.album_cover_url}"
      show.tracks.each(&:apply_id3_tags)

      puts "✅ #{show.url}"

      # Apply same image to children
      if Show.where(cover_art_parent_show_id: show.id).any?
        Show.where(cover_art_parent_show_id: show.id).each do |child|
          CoverArtImageService.call(show)
          AlbumCoverService.call(show)
          show.tracks.each(&:apply_id3_tags)
          puts "✅🔗 #{child.url}"
        end
      end

      pbar.increment if pbar
    rescue StandardError => e
      if e.message.include?("blocked") # Dall-E rejected the prompt
        puts "RETRYING #{show.date}"
        retry
      else
        binding.irb
      end
    end

    pbar.finish if pbar
  end
end
