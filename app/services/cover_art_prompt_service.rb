class CoverArtPromptService < BaseService
  param :show

  HUES = %w[
    Red Orange Yellow Green Blue Purple
    Red-Orange Yellow-Orange Yellow-Green Blue-Green
    Pink Magenta Vermilion
    Scarlet Cyan Teal Turquoise Indigo Lavender
    Amethyst Chartreuse Lime Crimson Maroon Olive
    Burgundy Ochre Beige Peach Mint Navy Coral
    Rose Amber Emerald Sapphire Violet Periwinkle
    Fuchsia Aquamarine Mint Apricot Mustard
    Tangerine Plum
  ]
  STYLES = %w[
    Abstract Impressionism Minimalism Expressionism
    Pop-Art Art-Deco Art-Nouveau Futurism Chinese-Brush-Painting
    Gothic Renaissance Wood-Burned Technical-Drawing
    Pointillism Fauvism Ink-Drawing Illustration
    Watercolor Line-Art Geometric Charcoal
    Low-Poly Pencil-Drawing Oil-Painting
    Pastel Stained-Glass Mosaics
    Woodcut Block-Prints Comic-Book
  ]
  BASE_PROMPT = <<~TXT
    We are going to generate an optimized prompt for DALL-E to create an artistic square image based on style, hue, and a few subjects pulled from a live musical performance.

    First, here is a **critical set of exclusions** that should never be included under any circumstances:
    - No jellyfish, horses, lighthouses, phoenixes, carousels or spinning tops.
    - Avoid instruments (guitars, saxophones, brass, classical instruments). No saxophones ever.
    - Avoid images of humans, human forms, or faces.
    - Avoid clocks, hourglasses, historical figures, and any text or symbols.
    - Avoid owls, foxes, flamingos, lobseters, raccoons, cats, lions, dolphins, waves, skeletons, dragons, unicorns, buffalo, tornadoes, cowboy hats, pyramids, violins, bats, bears, ferris wheels, churches, cathedrals, butterflies, pumpkins, gargoyles, and ghosts.
    - Avoid cliche landmarks like the Statue of Liberty, Golden Gate Bridge, Liberty Bell, Eiffel tower, and anything related to obvious geography (cornfields, cheese, moose, etc.).
    - Avoid swirls, vortexes, kaleidoscope, spirals, fractals, galaxies, meteors, - Avoid kites and and staircases.
    - Avoid references that DALL-E might reject as inappropriate.
    - Do not mention musical performances or the band Phish. Dall-e should not be aware of the context of the prompt.

    Now, let's generate the prompt:

    You will take **style**, **hue**, and **subjects** related to the performance and generate a creative prompt that avoids the aforementioned exclusions. Be creative with subjects, drawing from song titles and themes, but without emphasizing location too heavily. Often the subjects should be more abstract, inspired by themes in the setlist rather than the time and place. The subjects should be a random selection of 2 or 3 concepts pulled from the performance, but never include any of the excluded items listed above.

    Your JSON output should be in this format:

    {
      "subjects": "Skyscrapers, llamas, and a UFO",
      "prompt": "Create a rock album cover that includes images of skyscrapers, llamas, and a UFO in an abstract style with a blue hue."
    }

    Never mention any of the excluded items in the prompt. If necessary, create variations, but always respect the exclusions list.

    Always respond with pure JSON as specified above.
  TXT

  def call
    # If show is inside a run at same venue, defer
    return defer_to_kickoff_show if show != run_kickoff_show

    # Otherwise, generate a new prompt
    generate_new_prompt
  end

  private

  def generate_new_prompt
    show.update! \
      cover_art_style: style,
      cover_art_hue: hue,
      cover_art_prompt: chatgpt_response[:prompt],
      cover_art_parent_show_id: nil
  end

  def defer_to_kickoff_show
    show.update! \
      cover_art_parent_show_id: run_kickoff_show.id,
      cover_art_style: run_kickoff_show.cover_art_style,
      cover_art_hue: run_kickoff_show.cover_art_hue,
      cover_art_prompt: run_kickoff_show.cover_art_prompt
  end

  def run_kickoff_show
    kickoff_show = show
    loop do
      prior_show =
        Show.includes(tracks: :songs)
            .where("date < ?", kickoff_show.date)
            .order(date: :desc)
            .first

      # Break if prior show doesn't exist, is at a different venue,
      # or is more than 4 days apart (early shows at Hunt's / Nectar's)
      break unless prior_show && prior_show.venue_id == kickoff_show.venue_id
      break if (kickoff_show.date - prior_show.date).to_i > 4

      kickoff_show = prior_show
    end
    kickoff_show
  end

  # Select a hue from our list, voiding repetition of the previous show's hue
  def hue
    return @hue if defined?(@hue)
    available_hues = HUES.dup
    if prior_show&.cover_art_hue.present?
      available_hues.delete(prior_show.cover_art_hue)
    end
    @hue = available_hues.sample
  end


  # Select a style from our list, avoiding repetition of the previous show's style
  def style
    return @style if defined?(@style)
    available_styles = STYLES.dup
    if prior_show&.cover_art_style.present?
      available_styles.delete(prior_show.cover_art_style)
    end
    @style = available_styles.sample
  end

  # Fetch the previous show not at same venue to avoid duplication
  def prior_show
    return @prior_show if defined?(@prior_show)

    @prior_show =
      Show.where("date < ?", show.date)
          .where.not(venue: show.venue)
          .order(date: :desc)
          .first
    # Loop to last show if no prior show found
    @prior_show = Show.order(date: :desc).first if @prior_show.nil?
    @prior_show
  end

  def chatgpt_prompt
    return @chatgpt_prompt if defined?(@chatgpt_prompt)

    txt = BASE_PROMPT.dup
    txt += "\n\nHere is info about the show:\n"
    txt += "Date: #{show.date}\n"
    txt += "Venue: #{show.venue_name}\n"
    txt += "Location: #{show.venue.location}\n"
    # Don't include songs for runs to avoid songs that don't appear in a show
    # Since we use the same art for all shows in a run
    txt += "Songs: #{song_list}\n" if show != run_kickoff_show
    if prior_show.cover_art_prompt.present?
      txt +=
        "The previous show's prompt is this: " \
        "'#{prior_show.cover_art_prompt}'. Avoid the subjects from " \
        "that prompt as well as closely associated imagery. " \
        "Ignore style and hue of the previous prompt, " \
        "we'll specify those explicitly next.\n\n"
    end
    txt += "The hue of the art should be '#{hue}' and the style should be '#{style}'."
    @chatgpt_prompt = txt
  end

  def song_list
    unique_songs.map do
      artist = _1.original? ? "Phish" : _1.artist
      "#{_1.title} by #{artist}"
    end.join(", ")
  end

  def unique_songs
    @unique_songs ||= show.tracks.flat_map(&:songs).uniq
  end

  def chatgpt_response
    return @chatgpt_response if defined?(@chatgpt_response)

    response = Typhoeus.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{openai_api_token}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: "You are an expert in generating DALL-E prompts." },
          { role: "user", content: chatgpt_prompt }
        ]
      }.to_json
    )

    if response.success?
      response = JSON[response.body]["choices"].first["message"]["content"]
      response = response.gsub("```json", "").gsub("```", "") # Remove markdown
      @chatgpt_response = JSON.parse(response, symbolize_names: true)
    else
      raise "Failed to get response from ChatGPT: #{response.body}"
    end

    @chatgpt_response
  end

  def openai_api_token
    @openai_api_token ||= ENV.fetch("OPENAI_API_TOKEN")
  end
end
