class CoverArtVariety
  RECENT_RUNS = 6
  RECENCY_WEIGHTS = [ 1.0, 0.8, 0.6, 0.45, 0.3, 0.2 ].freeze
  NEIGHBORHOOD_DEGREES = 45
  TIE_MARGIN = 0.02

  HUES = {
    "Red" => 0, "Scarlet" => 5, "Vermilion" => 12, "Coral" => 16, "Red-Orange" => 20,
    "Tangerine" => 28, "Orange" => 32, "Amber" => 40, "Gold" => 48, "Mustard" => 52,
    "Yellow" => 58, "Lime" => 80, "Yellow-Green" => 90, "Green" => 120, "Emerald" => 140,
    "Mint" => 150, "Blue-Green" => 165, "Teal" => 180, "Cyan" => 188, "Cerulean" => 200,
    "Blue" => 225, "Indigo" => 250, "Violet" => 268, "Purple" => 285, "Plum" => 300,
    "Magenta" => 312, "Pink" => 330, "Crimson" => 348
  }.freeze

  STYLES = %w[
    Poster-Art Vintage-Travel-Poster Psychedelic-Poster Screen-Print Risograph
    Linocut Woodcut Illustration Storybook-Illustration Ink-Drawing Ink-Wash
    Colored-Pencil Charcoal Watercolor Gouache Oil-Painting Impasto Pastel
    Art-Deco Art-Nouveau Ukiyo-e Stained-Glass Paper-Collage Papercut
    Photograph Film-Photograph Double-Exposure Isometric Low-Poly
  ].freeze

  attr_reader :show, :random

  def initialize(show, random: Random.new)
    @show = show
    @random = random
  end

  def hue
    @hue ||= begin
      scores = HUES.transform_values { crowding(it) }
      floor = scores.values.min
      scores.select { |_name, score| score <= floor + TIE_MARGIN }.keys.sample(random:)
    end
  end

  def styles(count)
    fresh = STYLES.reject { used_recently?(it) }
    (fresh.size >= count ? fresh : STYLES).sample(count, random:)
  end

  def recent_prompts
    recent_runs.filter_map { it.cover_art_prompt.presence }
  end

  private

  def recent_runs
    @recent_runs ||=
      Show.joins(:cover_art_attachment)
          .where(date: ...show.cover_art_run_kickoff.date, cover_art_parent_show_id: nil)
          .order(date: :desc)
          .limit(RECENT_RUNS)
          .to_a
  end

  def recent_palettes
    @recent_palettes ||= recent_runs.map { palette_of(it) }
  end

  def palette_of(run)
    CoverArtPalette.call(run.cover_art.blob)
  rescue ActiveStorage::FileNotFoundError, MiniMagick::Error => e
    Rails.logger.warn("Cover art palette unavailable for #{run.date}: #{e.message}")
    nil
  end

  def crowding(degrees)
    recent_palettes.each_with_index.sum do |palette, index|
      next 0.0 if palette.nil?
      RECENCY_WEIGHTS.fetch(index) * palette["colorfulness"] * mass_near(palette["histogram"], degrees)
    end
  end

  def mass_near(histogram, degrees)
    histogram.each_with_index.sum do |mass, bin|
      center = (bin * CoverArtPalette::BIN_DEGREES) + (CoverArtPalette::BIN_DEGREES / 2)
      angular_gap(center, degrees) < NEIGHBORHOOD_DEGREES ? mass : 0.0
    end
  end

  def angular_gap(a, b)
    ((a - b + 180) % 360 - 180).abs
  end

  def used_recently?(style)
    name = style.tr("-", " ").downcase
    recent_prompts.any? { it.tr("-", " ").downcase.include?(name) }
  end
end
