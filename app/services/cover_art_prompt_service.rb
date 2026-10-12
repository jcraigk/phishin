class CoverArtPromptService < ApplicationService
  param :show
  option :dry_run, default: -> { false }
  option :model, default: -> { MODELS.first }
  option :random, default: -> { Random.new }

  class Error < StandardError; end

  MODELS = %w[anthropic/claude-opus-5].freeze
  CANDIDATES = 4
  SUFFIX = "Square album cover, illustrated artwork, not photorealistic, full-bleed composition " \
           "filling the frame, no text, letters, numbers, borders or watermarks.".freeze
  TAPER_NOTES_LIMIT = 600
  TRANSCRIPT_LIMIT = 300
  EXAMPLES = [
    "Poster art of Colorado mountains with a single car driving on an interstate, brown hue",
    "A baseball hit at high velocity out of a ballpark into blue sky with fluffy clouds, " \
    "a velocity trail behind the ball, poster art style",
    "Poster art of a 1990s boom box on a city street with graffiti in the background, overall neon pink color",
    "A soft-serve ice cream cone in a summer rainstorm, poster art with a consistent color scheme",
    "An old home by a southern river, illustration with orange highlights over a dark green palette",
    "The Philadelphia skyline overgrown by trees, illustration style in a green hue",
    "A confused, intoxicated firefly on a city block, ink drawing with a yellow-orange hue",
    "Overhead view of a tropical beach with a single colorful umbrella and its shadow, color illustration",
    "A glass box with a rainstorm over a forest inside it, divided sky"
  ].freeze
  SYSTEM = "You are an art director commissioning album covers for live concert recordings.".freeze

  def call
    if dry_run
      { prompt: prompts.first, prompts:, hue: variety.hue, styles: }
    elsif show == show.cover_art_run_kickoff
      show.update!(cover_art_prompt: prompts.first, cover_art_parent_show_id: nil)
      print_alternatives
    else
      defer_to_kickoff_show
    end
  end

  private

  def prompts
    @prompts ||= begin
      list = Array(llm_response[:prompts]).map { it.to_s.strip }.compact_blank.first(CANDIDATES)
      raise Error, "#{model} returned no cover art prompts" if list.empty?
      list.map { "#{it.delete_suffix('.')}. #{SUFFIX}" }
    end
  end

  def variety
    @variety ||= CoverArtVariety.new(show, random:)
  end

  def styles
    @styles ||= variety.styles(CANDIDATES)
  end

  def print_alternatives
    prompts.drop(1).each { puts "  • #{it}" }
  end

  def defer_to_kickoff_show
    kickoff = show.cover_art_run_kickoff
    show.update! \
      cover_art_parent_show_id: kickoff.id,
      cover_art_prompt: kickoff.cover_art_prompt
  end

  def llm_response
    @llm_response ||= OpenRouter.extract_json(
      OpenRouter.chat(model:, system: SYSTEM, prompt: brief).text, symbolize_names: true
    )
  end

  def brief
    [ instructions, assignments, show_context, recent_section, examples_section, response_format ].join("\n\n")
  end

  def instructions
    <<~TXT.strip
      Write #{CANDIDATES} image-generation prompts for the cover art of the live Phish show described below. Each prompt is for a different candidate cover; the admin will pick one.

      Each prompt must:
      - Describe one strong, concrete scene that can be painted or drawn, with at most two main elements composed together naturally. No abstract concepts.
      - Give the scene a setting that evokes the place or the season, and state the viewpoint or framing (overhead view, close-up, wide landscape and so on).
      - Draw its idea from a different source than the other prompts: something that happened at this show (setlist notes, banter, tags), a song played (turn titles and lyrics into concrete images), the city, venue and region (landmarks, landscape, wildlife, plants, regional food), or the season and any nearby holiday. Wit and whimsy are welcome.
      - Describe illustrated or printed artwork, never photography or 3D renders. Leave out camera language such as lens, depth of field, film grain, exposure or bokeh.
      - Contain no people, faces, band members, logos, brand names, text, borders or decorative frames.
      - Read like the examples: one to three plain sentences, at most 60 words.
    TXT
  end

  def assignments
    lines = styles.each_with_index.map do |style, i|
      "- Prompt #{i + 1}: #{style.tr('-', ' ').downcase} (#{CoverArtVariety::STYLES.fetch(style)})"
    end
    <<~TXT.strip
      Color: every prompt's palette must be built around #{variety.hue} as the dominant color, described in words with one or two supporting colors, so the cover clearly reads as #{variety.hue} at thumbnail size. Covers are scanned in a list, so this color keeps neighboring shows distinct.

      Style: use exactly this style for each prompt, and let its description shape how the scene is rendered.
      #{lines.join("\n")}
    TXT
  end

  def show_context
    sections = [
      "Show: #{show.venue_name}, #{show.venue.location} on #{show.date.strftime('%A, %B %-d, %Y')} (#{season})",
      ("Tour: #{show.tour.name}" if show.tour),
      "Setlist (song by artist):\n#{setlist}",
      ("Phish.net setlist notes: #{setlist_notes}" if setlist_notes.present?),
      ("Tags:\n#{tag_lines.join("\n")}" if tag_lines.any?),
      ("Taper notes (mostly recording details; use only what describes the event): " \
       "#{show.taper_notes.truncate(TAPER_NOTES_LIMIT)}" if show.taper_notes.present?)
    ]
    sections.compact.join("\n\n")
  end

  def season
    { 12 => "winter", 1 => "winter", 2 => "winter", 3 => "spring", 4 => "spring", 5 => "spring",
      6 => "summer", 7 => "summer", 8 => "summer" }.fetch(show.date.month, "autumn")
  end

  def setlist
    show.tracks.includes(:songs).order(:position).group_by(&:set_name).map do |set_name, tracks|
      songs = tracks.map { |track| "#{track.title} by #{track.songs.first&.artist.presence || 'Phish'}" }
      "#{set_name}: #{songs.join(', ')}"
    end.join("\n")
  end

  def tag_lines
    @tag_lines ||= begin
      show_tags = show.show_tags.includes(:tag).map { [ it.tag.name, it.notes ].compact_blank.join(": ") }
      track_tags = TrackTag.joins(:track).where(tracks: { show_id: show.id }).includes(:tag, :track)
                           .order("tracks.position").map { track_tag_line(it) }
      (show_tags + track_tags).map { "- #{it}" }
    end
  end

  def track_tag_line(track_tag)
    parts = [ "#{track_tag.track.title} (#{track_tag.tag.name})", track_tag.notes.presence,
              track_tag.transcript.presence&.squish&.truncate(TRANSCRIPT_LIMIT) ]
    parts.compact.join(": ")
  end

  def setlist_notes
    return @setlist_notes if defined?(@setlist_notes)
    @setlist_notes = fetch_setlist_notes
  end

  def fetch_setlist_notes
    url = "https://api.phish.net/v5/shows/showdate/#{show.date}.json?apikey=#{ENV.fetch('PNET_API_KEY', '')}"
    response = Typhoeus.get(url)
    return nil unless response.success?
    notes = JSON.parse(response.body).dig("data", 0, "setlist_notes")
    notes && ActionController::Base.helpers.strip_tags(notes).squish.presence
  rescue JSON::ParserError
    nil
  end

  def recent_section
    recent = variety.recent_prompts
    return nil if recent.empty?
    "Prompts used for the most recent covers. Don't repeat their subjects:\n#{recent.map { "- #{it}" }.join("\n")}"
  end

  def examples_section
    "Examples of prompts the admin likes:\n#{EXAMPLES.map { "- #{it}" }.join("\n")}"
  end

  def response_format
    %(Respond with only a JSON object of the form {"prompts": ["...", "...", "...", "..."]}, in the order of the style assignments.)
  end
end
