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
    Pointillism Fauvism Ink-Drawing
    Watercolor Line-Art Geometric Charcoal
    Low-Poly Pencil-Drawing Oil-Painting
    Ukiyo-e Pastel Stained-Glass Mosaics
    Woodcut Block-Prints
  ]
  BASE_PROMPT = <<~TXT
    We are going to generate an optimized prompt for DALL-E to create an artistic square image based on style, hue, and a few subjects pulled from a live musical performance held in the real world. I will provide general information of the event including time, place, and setlist. I will also provide data for a previous event to avoid repetition of imagery. The format of your response will take this JSON format. Always respond with pure JSON and always include "subjects" and "prompt" keys. Here is an example:

    {
      "subjects": "Skyscrapers, llamas, and a UFO",
      "prompt": "Create a rock album cover that includes images of skyscrapers, llamas, and a ufo in an abstract style with a blue hue",
    }

    The subjects should be a comma separated list of 2 or 3 concepts or images pulled from the event info. You should have a 50% chance of selecting either 2 or 3 subjects for each prompt. Be creative in how these subjects are selected. Consider the time and location of the concert but don't over-emphasize this. We want randomness in the images, especially as they relate to the content of the songs played in the show. If a setlist is provided, include the song titles and your knowledge of song lyrical content in consideration. Favor popular songs over obscure ones. Consider cultural and artistic impressions of the songs played at the show to add to the pool of potential imagery. If there appear to be themes in the song selections, favor that. Lean into famous landmarks and famous songs/lyrics and other imagery, but avoid the Liberty Bell and the Statue of Liberty and apples in new york and cheese in wisconsin, that kind of thing. Never include those in your prompt. Don't be afraid to get creative and silly in some cases. If the show is not in the United States, lean into cultural/geographic references for the foreign country. If the show takes place in a unique location, lean into that uniqueness. For shows that take place on halloween, take note of the cover songs played and lean into that. Season and weather should also be considered.

    Avoid images of musical instruments like guitars or keyboards. Avoid images of saxophones, trumpets, and other brass instruments. Avoid images of classical instruments like french horns and string instruments. NO SAXOPHONES EVER. Avoid mentioning surrealism.

    Avoid mention of humans, human forms, or faces. Avoid historical figures. Avoid images of clocks or hourglasses. Avoid references that will lead to text and symbols being included in the image. Avoid jellyfish. Avoid musical notes. Avoid chesire cats. Avoid anything that Dall-e will reject as inappropriate.

    Never reference cliche obvious landmarks. If the show takes place at Saratoga Performing Arts Center, do not use horse or carousel imagery. Avoid phoenix imagery always. I repeat, DO NOT use carousel imagery at SPAC, pick something else. Avoid pumpkins always. Avoid dolphins and lobsters and lighthouses. Avoid owls, foxes, flamingos, badges, fireflies, dragonflies, dragons, bats, buffalo, twisters, tornadoes, cowboy hats, unicorns, pyramids, raccoons, tigers, squirrels, armadillos, ferris wheels, churches, cathedrals, ghosts, and bears of any kind.

    Use your best knowledge about Dall-e to generate an optimized prompt and provide the full text of the prompt in the 'prompt' key of your JSON response. Be sure this prompt includes indication of style, hue, subjects, and any other relevant information for a visually pleasing and unique piece of art.

    Your prompt should begin with "Create an image in x style with y hue." and then get creative with the subjects but do not specify any other styles or hues/colors beyond the initial specification.

    Always respond with pure JSON. Do not include any markdown formatting, such as backticks or newlines outside of JSON structure.

    NEVER MENTION THE LIBERTY BELL. NEVER MENTION CAROUSELS. NEVER MENTION JELLYFISH.

    Don't consider the location in every prompt, often it should be more disassociative and abstract and be more related to the titles or themes of the setlist than the time and place.
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
