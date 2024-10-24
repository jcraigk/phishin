class CoverArtPromptService < BaseService
  param :show

  HUES = %w[
    Red Orange Yellow Green Blue Purple
    Red-Orange Yellow-Orange Yellow-Green
    Pink Magenta Vermilion Blue-Green Cerulean
    Scarlet Cyan Teal Turquoise Indigo Lavender
    Amethyst Lime Mint Crimson Maroon
    Beige Peach Coral Amber Emerald Violet
    Apricot Mustard Tangerine Plum Gold
  ]
  STYLES = %w[
    Futurism Wood-Burned Poster-Art
    Ink-Drawing Illustration Nihonga
    Watercolor Line-Art Geometric Low-Poly
    Oil-Painting Technical-Drawing
    Block-Prints Comic-Book Photograph Isometric-Drawing
  ]
  CATEGORIES = %w[animals plants foods misc_objects time_concepts phish]
  BASE_PROMPT = <<~TXT
    I want you to generate a series of objects and ideas in specific categories associated with a venue, time, and city/state I provide below. I want the answer in JSON format. The keys should be animals, plants, foods, misc_objects (miscellaneous objects), time_concepts (concepts related to time, season, social atmosphere, etc), and phish (explained below). I want you to give me ten words or phrases representing those categories. Avoid references that DALL-E might reject as inappropriate. Avoid images of humans, human forms, or faces.

    The subjects in every category should reflect the time and place as well as content pulled from song titles. So, for example, if it's winter in New York, you wouldn't mention insects or other animals/plants not found during that time of year in that place. The "foods" key should similary be restricted to items that are commonly found in the area and are associated with the time of year. Take note of Halloween, Christmas, New Year's, and other holiday seasons.

    The "phish" key should include imagery pulled from the list of songs played at the show. This should include titles and your general knowledge of the lyrics. This should include both their originals and covers.

    Be creative and random in your selections, especially when it comes to miscellaneous objects category. Those can incude other creatures from the tree of life, images from science and art, pop culture, etc. Choose not only the most relevant to the time/place given, but some loosely related objects/visuals/concepts. Make sure all of your selections have a visual element to them. Prefix words with "a" or "an" as needed.

    Here is an example if the time and place were Madison Square, New York City on December 31, 2021:

    {
      "animals": [
        "a pigeon",
        "a rat",
        "a sparrow",
        "a falcon",
        "a hawk",
        "a cockroach",
        "a squirrel",
        "a starling",
        "a house mouse",
        "a striped skunk"
      ]
      "plants": [
        "ivy creeping over stone",
        "potted rosemary",
        "snow-dusted grass",
        "bamboo stalks",
        "an aloe plant in window",
        "a wild dandelion sprout",
        "urban moss patch",
        "rooftop garden basil",
        "a succulent",
        "a frozen fern"
      ],
      "foods": [
        "a cinnamon pretzel",
        "a slice of New York pizza",
        "a churro",
        "roasted peanuts",
        "hot cider",
        "a bag of chestnuts",
        "a steaming hot dog",
        "a sesame bagel",
        "candy apple",
        "an empanada"
      ],
      "misc_objects": [
        "a frosted window pane",
        "a subway sign",
        "a discarded coffee cup",
        "a streetlight glow",
        "sparkling confetti",
        "a bicycle lock",
        "a neon glow reflection in puddle",
        "a metal park bench",
        "a fire hydrant with scarf",
        "a sidewalk crack with snow"
      ],
      "time_concepts": [
        "a midnight chill",
        "frozen breath in the air",
        "the last moments of the year",
        "a winter night buzz",
        "a holiday glow",
        "festive anticipation",
        "crisp midnight air",
        "twinkling streetlights",
        "evening stillness",
        "a city's breath before midnight"
      ],
      "phish": [
        "an oar",
        "clouds in the sky",
        "a cruise ship",
        "spaghetti",
        "strawberry goo",
        "sugar shack",
        "rock and roll",
        "a dog",
        "a cat"
        "a horse"
      ]
    }

    Respond only with the JSON object containing the keys and values for the categories. Do not include any other information or formatting characters in your response such as backticks or the token "json".
  TXT
  def call
    if show == run_kickoff_show
      generate_new_prompt
      print_response_hints
      # puts @chatgpt_response
      # puts @new_prompt
    else
      defer_to_kickoff_show
    end
  end

  private

  def new_prompt
    return @new_prompt if defined?(@new_prompt)
    num = rand < 0.3 ? 1 : 2
    subjects = CATEGORIES.sample(num).map { chatgpt_response[_1.to_sym].sample }.join(" and ")
    @new_prompt =
      "Create an image featuring #{subjects} " \
      "in the style of #{style} with a #{hue} hue."
  end

  def print_response_hints
    txt = CATEGORIES.map do |category|
      "#{category.upcase} " + chatgpt_response[category.to_sym].sample(3).join(", ")
    end.join(" / ")
    puts txt
  end

  def song_list
    show.tracks.map do
      "#{_1.title} by #{_1.songs.first.artist || 'Phish'}"
    end.join(", ")
  end

  def generate_new_prompt
    show.update! \
      cover_art_style: style,
      cover_art_hue: hue,
      cover_art_prompt: new_prompt,
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

  def chatgpt_response
    return @chatgpt_response if defined?(@chatgpt_response)

    prompt = BASE_PROMPT.dup
    prompt += "\nThe songs played at this show were: #{song_list}"
    prompt += "\n\nThe time and place is #{show.venue_name}, #{show.venue.location} on #{show.date}"
    # puts prompt

    response = Typhoeus.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{openai_api_token}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: "You are a generalized expert in knowledge about points of interest." },
          { role: "user", content: prompt }
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
