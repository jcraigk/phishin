class CoverArtPromptService < BaseService
  param :show

  HUES = %w[
    Red Orange Yellow Green Blue Purple
    Red-Orange Yellow-Orange Yellow-Green Blue-Green
    Blue-Violet Red-Violet Pink Magenta Vermilion
    Scarlet Cyan Teal Turquoise Indigo Lavender
    Amethyst Chartreuse Lime Crimson Maroon Olive
    Burgundy Ochre Beige Peach Mint Navy Coral
    Rose Amber Emerald Sapphire Violet Periwinkle
    Fuchsia Aquamarine Mint\ Green Apricot Mustard
    Tangerine Plum
  ]
  STYLES = %w[
    Abstract Impressionism Cubism Surrealism Minimalism Expressionism
    Pop-Art Art-Deco Art-Nouveau Futurism Dadaism Bauhaus
    Gothic Baroque Romanticism Renaissance Neo-Expressionism
    Pointillism Fauvism Graffiti Collage Ink-Drawing
    Watercolor Line-Art Cartoon Geometric Psychedelic
    Pixel-Art Low-Poly Vaporwave Retro Vintage
    Ukiyo-e Pastel Stained-Glass Mosaics
    Woodcut Block-Prints Cyberpunk Steampunk
  ]
  BASE_PROMPT = <<~TXT
    We are going to generate an optimized prompt for DALL-E to create an artistic square image based on style, hue, and a few subjects pulled from a live musical performance held in the real world. I will provide general information of the event including time, place, and setlist. I will also provide data for a previous event to avoid repetition of imagery. The format of your response will take this JSON format. Always respond with pure JSON and always include "subjects" and "prompt" keys. Here is an example:

    {
      "subjects": "Skyscrapers, llamas, and a UFO",
      "prompt": "Create a rock album cover that includes images of skyscrapers, llamas, and a ufo in an abstract style with a blue hue",
    }

    The subjects should be a comma separated list of 3 concepts or images pulled from the event info. Take liberty here and be creative in how these subjects are selected. Consider the time and location of the concert as well as imagery in the song lyrics. Favor well recognized songs over obscure ones. Consider cultural and artistic impressions of the songs played at the show to add to the pool of potential imagery. If there appear to be themes in the song selections, favor that. Lean into famous landmarks and famous songs/lyrics and other imagery. Don't be afraid to get creative and silly in some cases. If the show is not in the united states, lean into cultural/geographic references for the foreign country. If the show takes place in a unique location, lean into that uniqueness. For shows that take place on halloween, take note of the cover songs played and lean into that. Season and weather should also be considered.

    Do not let Dall-e know that the art is related to a concert, but rather be general about prompting it to generate an art piece based on the selected subjects. Do not let Dall-e generate text or symbols.

    Use your best knowledge about Dall-e to generate an optimized prompt and provide the full text of the prompt in the 'prompt' key of your JSON response. Be sure this prompt includes indication of style, hue, subjects, and any other relevant information for a visually pleasing and unique piece of art.

    Your prompt should begin with "Create an image in x style with y hue." and then get creative with the subjects but do not specify any other styles or hues/colors beyond the initial specification.

    Always respond with pure JSON. Do not include any markdown formatting, such as backticks or newlines outside of JSON structure.
  TXT

  def call
    # If show is inside a run at same venue, use same prompt
    # return use_prompt_from_run if show != run_kickoff_show

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
    puts chatgpt_response[:prompt]
  end

  def use_prompt_from_run
    show.update!(cover_art_parent_show_id: run_kickoff_show.id)
    puts "Using prompt from run (#{run_kickoff_show.date})"
  end

  def run_kickoff_show
    kickoff_show = show
    loop do
      prior_show =
        Show.includes(tracks: :songs)
            .where("date < ?", kickoff_show.date)
            .order(date: :desc)
            .first
      break unless prior_show && prior_show.venue_id == kickoff_show.venue_id
      kickoff_show = prior_show
    end
    kickoff_show
  end

  # Select a hue from our list, selecting a less used one
  # and avoiding repetition of the previous show's hue
  def hue
    return @hue if defined?(@hue)

    available_hues = HUES.dup
    if prior_show&.cover_art_hue.present?
      available_hues.delete(prior_show.cover_art_hue)
    end

    hue_usage = Show.where.not(cover_art_hue: nil).group(:cover_art_hue).count
    sorted_hues = available_hues.sort_by { hue_usage[_1] || 0 }
    min_usage = hue_usage[sorted_hues.first] || 0
    bottom_tier_hues = sorted_hues.select { hue_usage[_1] == min_usage || hue_usage[_1].nil? }

    @hue = bottom_tier_hues.sample
  end


  # Select a style from our list, selecting a less used one
  # and avoiding repetition of the previous show's style
  def style
    return @style if defined?(@style)

    available_styles = STYLES.dup
    if prior_show&.cover_art_style.present?
      available_styles.delete(prior_show.cover_art_style)
    end

    style_usage = Show.where.not(cover_art_style: nil).group(:cover_art_style).count
    sorted_styles = available_styles.sort_by { style_usage[_1] || 0 }
    min_usage = style_usage[sorted_styles.first] || 0
    bottom_tier_styles = sorted_styles.select {
 style_usage[_1] == min_usage || style_usage[_1].nil? }

    @style = bottom_tier_styles.sample
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
    txt += "Songs: #{song_list}\n"
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

    content = chatgpt_prompt + "\n\nDo not include any text, words, or numbers in the image."

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
