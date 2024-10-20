class InteractiveCoverArtService < BaseService
  extend Dry::Initializer

  param :relation

  attr_accessor :pbar

  NUM_IMAGES = 2

  def call
    setup_progress_bar if relation.count > 1
    interactive_cli
  end

  def setup_progress_bar
    @pbar = ProgressBar.create \
      total: relation.count,
      format: "%a %B %c/%C %p%% %E"
  end

  def interactive_cli
    relation.each_with_index do |show, index|
      @urls = []

      display_show_info(show)
      handle_cover_art_prompt(show)

      if handle_cover_art_images(show)
        apply_album_cover_and_id3_tags(show)
        apply_cover_art_to_children(show)
      end

      pbar.increment if pbar
    end

    pbar.finish if pbar
  rescue StandardError => e
    binding.irb
  end

  def display_show_info(show)
    formatted_date = show.date.strftime("%b %-d, %Y")
    puts "=================================="
    puts "🏟  \e]8;;#{show.url}\a#{formatted_date}\e]8;;\a - #{show.venue_name} - #{show.venue.location}"
    if show.cover_art_parent_show_id.present?
      parent_show = Show.find(show.cover_art_parent_show_id)
      parent_date = parent_show.date.strftime("%b %-d, %Y")
      puts "🔗  Parent: \e]8;;#{parent_show.url}\a#{parent_date}\e]8;;\a"
    end
  end

  def handle_cover_art_prompt(show)
    return unless show.cover_art_parent_show_id.nil?

    if show.cover_art_prompt.blank?
      puts "Generating prompt..."
      CoverArtPromptService.call(show)
      @urls = []
    end
    puts "💬 #{show.cover_art_prompt}"
  end

  def handle_cover_art_images(show)
    if show.cover_art_parent_show_id.present?
      use_parent_cover_art(show)
      return true
    end

    loop do
      input = prompt_user_for_action

      # If the input is longer than 1 character, treat it as a custom prompt
      if input.length > 1
        handle_custom_prompt(show, input)
        next
      end

      result = process_input(show, input)
      return result if result.in?([true, false])
    end
    true
  end

  def handle_custom_prompt(show, input)
    puts "💬 #{input}"
    show.update!(cover_art_prompt: input)
    @urls = []
    generate_candidate_images(show)
  end

  def prompt_user_for_action
    txt = @urls.any? ? "Use (1-#{@urls.size}), " : ""
    txt += "(S)kip, Gen (i)mages, Gen (p)rompt, (U)RL, or custom prompt 👉 "
    print txt
    $stdin.gets.chomp
  end

  def process_input(show, input)
    case input.downcase
    when "i", "p"
      handle_image_or_prompt(show, input)
      nil
    when "u"
      attach_cover_art_from_url(show)
      true
    when /\d+/
      attach_selected_image(show, @urls[input.to_i - 1])
      true
    when "s"
      puts "Skipping..."
      false
    else
      puts "Invalid input, skipping..."
      false
    end
  end

  def handle_image_or_prompt(show, input)
    if input == "p"
      puts "Generating cover art prompt..."
      CoverArtPromptService.call(show)
      @urls = []
      puts "💬 #{show.cover_art_prompt}"
    end
    generate_candidate_images(show)
  end

  def attach_cover_art_from_url(show)
    print "URL 👉 "
    url = $stdin.gets.chomp
    show.attach_cover_art_by_url(url)
  end

  def attach_selected_image(show, image_url)
    show.attach_cover_art_by_url(image_url)
  end

  def generate_candidate_images(show)
    puts "Generating #{NUM_IMAGES} candidate images..."

    NUM_IMAGES.times do |i|
      image_url = CoverArtImageService.call(show, dry_run: true)
      @urls << image_url
      puts "\e]8;;#{image_url}\aImage ##{@urls.size}\e]8;;\a"
      display_image_in_terminal(image_url)
    end
  end

  def display_image_in_terminal(image_url)
    return unless system("which timg > /dev/null 2>&1")
    system("timg --pixelation=iterm2 -g 120x120 \"#{image_url}\" 2>/dev/null")
  end

  def use_parent_cover_art(show)
    puts "Using parent cover art image..."
    show.cover_art.attach(Show.find(show.cover_art_parent_show_id).cover_art.blob)
    true
  end

  def apply_album_cover_and_id3_tags(show)
    AlbumCoverService.call(show)
    display_image_in_terminal(show.album_cover_url)
    show.tracks.each(&:apply_id3_tags)
    puts "✅ \e]8;;#{show.url}\a#{show.date.strftime("%b %-d, %Y")}\e]8;;\a"
  end

  def apply_cover_art_to_children(show)
    Show.where(cover_art_parent_show_id: show.id).each do |child_show|
      CoverArtImageService.call(child_show)
      AlbumCoverService.call(child_show)
      child_show.tracks.each(&:apply_id3_tags)
      puts "✅🔗 \e]8;;#{child_show.url}\a#{child_show.date.strftime("%b %-d, %Y")}\e]8;;\a"
    end
  end
end
