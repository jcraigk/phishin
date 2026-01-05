class StageNotesSyncService < ApplicationService
  # TODO: Remove when phish.net corrects 1989-10-13 setlist
  SKIP_DATES = %w[1989-10-13].freeze

  option :date, default: -> { nil }
  option :dates, default: -> { nil }
  option :start_date, default: -> { nil }
  option :end_date, default: -> { nil }
  option :all, default: -> { false }
  option :dry_run, default: -> { false }
  option :verbose, default: -> { false }
  option :model, default: -> { "claude-opus-4-5-20251101" }
  option :delay, default: -> { 3 }

  def call
    validate_options!
    @stage_notes_tag = Tag.find_by!(slug: "stage-notes")
    shows = fetch_shows

    puts "Analyzing #{shows.count} show(s)#{dry_run ? ' (DRY RUN)' : ''}..."
    pbar = ProgressBar.create(total: shows.count, format: "%a %B %c/%C %p%% %E")

    @show_tagged = 0
    @show_updated = 0
    @track_tagged = 0
    @track_updated = 0
    @skipped = 0
    @input_tokens = 0
    @output_tokens = 0

    shows.each_with_index do |show, index|
      process_show(show)
      pbar.increment
      sleep(delay) if delay.positive? && index < shows.size - 1
    end

    puts "\nComplete!"
    puts "  Shows:  Tagged: #{@show_tagged}, Updated: #{@show_updated}"
    puts "  Tracks: Tagged: #{@track_tagged}, Updated: #{@track_updated}"
    puts "  Skipped: #{@skipped}"
    puts "  Tokens: #{@input_tokens.to_fs(:delimited)} input, #{@output_tokens.to_fs(:delimited)} output"
    puts "  Cost:   $#{format_cost(calculate_cost)}"
  end

  private

  def validate_options!
    return if date || dates || start_date || end_date || all
    raise ArgumentError, "Must specify DATE, DATES, START_DATE, END_DATE, or ALL=true"
  end

  def fetch_shows
    scope = if date
      Show.where(date:)
    elsif dates
      Show.where(date: dates.split(",").map(&:strip))
    elsif start_date && end_date
      Show.where(date: start_date..end_date)
    elsif start_date
      Show.where("date >= ?", start_date)
    elsif end_date
      Show.where("date <= ?", end_date)
    else
      Show.all
    end
    scope.includes(:tracks, :tags).order(date: :asc)
  end

  def process_show(show)
    if SKIP_DATES.include?(show.date.to_s)
      @skipped += 1
      return
    end

    notes = fetch_setlist_notes(show.date)
    if notes.blank?
      @skipped += 1
      return
    end

    track_info = show.tracks.order(:position).map { |t| { title: t.title, set: t.set_name } }
    @existing_tag_notes = gather_existing_tag_notes(show)
    analysis = analyze_with_llm(notes, track_info, @existing_tag_notes, show.date)

    show_notes = analysis[:show_notes]
    track_notes = analysis[:track_notes].presence || []

    # Filter out Banter tracks - they already explain the content
    track_notes = track_notes.reject { |tn| tn["song_title"].downcase == "banter" }

    apply_show_tag(show, show_notes) if show_notes.present?
    apply_track_tags(show, track_notes) if track_notes.any?

    @skipped += 1 if show_notes.blank? && track_notes.empty?
  rescue StandardError => e
    puts "\n✗ Error processing #{show.date}: #{e.message}"
    @skipped += 1
  end

  def apply_show_tag(show, extracted_notes)
    existing = ShowTag.find_by(show:, tag: @stage_notes_tag)

    if existing
      return if existing.notes == extracted_notes
      if dry_run
        puts "\n[DRY RUN] Would update show: #{show.date}"
        puts "  Old: \e[36m#{existing.notes}\e[0m"
        puts "  New: \e[36m#{extracted_notes}\e[0m"
      else
        existing.update!(notes: extracted_notes)
        puts "\n🏟️ Show updated: #{show.date}"
        puts "  \e[36m#{extracted_notes}\e[0m" if verbose
      end
      @show_updated += 1
    else
      if dry_run
        puts "\n[DRY RUN] Would tag show: #{show.date}"
        puts "  \e[36m#{extracted_notes}\e[0m"
      else
        ShowTag.create!(show:, tag: @stage_notes_tag, notes: extracted_notes)
        puts "\n🏟️ Show tagged: #{show.date}"
        puts "  \e[36m#{extracted_notes}\e[0m" if verbose
      end
      @show_tagged += 1
    end
  end

  def apply_track_tags(show, track_notes)
    track_notes = track_notes.uniq { |tn| tn["song_title"] }
    track_notes.each do |track_note|
      track = find_track(show, track_note["song_title"])
      next unless track

      existing = TrackTag.find_by(track:, tag: @stage_notes_tag)
      notes = track_note["notes"]

      if existing
        next if existing.notes == notes
        if dry_run
          puts "\n[DRY RUN] Would update track: #{show.date} - #{track.title}"
          puts "  Old: \e[36m#{existing.notes}\e[0m"
          puts "  New: \e[36m#{notes}\e[0m"
        else
          existing.update!(notes:)
          puts "\n🎸 Track updated: #{show.date} - #{track.title}"
          puts "  \e[36m#{notes}\e[0m" if verbose
        end
        @track_updated += 1
      else
        if dry_run
          puts "\n[DRY RUN] Would tag track: #{show.date} - #{track.title}"
          puts "  \e[36m#{notes}\e[0m"
        else
          TrackTag.create!(track:, tag: @stage_notes_tag, notes:)
          puts "\n🎸 Track tagged: #{show.date} - #{track.title}"
          puts "  \e[36m#{notes}\e[0m" if verbose
        end
        @track_tagged += 1
      end
    end
  end

  def find_track(show, song_title)
    show.tracks.find { |t| t.title.downcase == song_title.downcase } ||
      show.tracks.find { |t| t.title.downcase.include?(song_title.downcase) } ||
      show.tracks.find { |t| song_title.downcase.include?(t.title.downcase) }
  end

  def gather_existing_tag_notes(show)
    show_tags = ShowTag.includes(:tag).where(show:)
    track_tags = TrackTag.includes(:tag, :track).where(track: show.tracks)

    {
      show: show_tags.map { |st| { tag: st.tag.name, notes: st.notes.presence } },
      tracks: track_tags.map { |tt| { track: tt.track.title, tag: tt.tag.name, notes: tt.notes.presence } }
    }
  end

  def fetch_setlist_notes(show_date)
    url = "https://api.phish.net/v5/shows/showdate/#{show_date}.json?apikey=#{pnet_api_key}"
    response = Typhoeus.get(url)
    return nil unless response.success?

    data = JSON.parse(response.body)
    return nil unless data["data"]&.any?

    data["data"].first["setlist_notes"]
  end

  def analyze_with_llm(notes, track_info, existing_tag_notes, show_date)
    prompt = build_prompt(notes, track_info, existing_tag_notes)

    if model.start_with?("claude")
      analyze_with_claude(prompt, show_date)
    else
      analyze_with_openai(prompt, show_date)
    end
  end

  def analyze_with_openai(prompt, show_date)
    response = Typhoeus.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{openai_api_token}",
        "Content-Type" => "application/json"
      },
      body: {
        model:,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: prompt }
        ],
        temperature: 0,
        response_format: { type: "json_object" }
      }.to_json
    )

    if response.success?
      result = JSON.parse(response.body)
      input = result.dig("usage", "prompt_tokens").to_i
      output = result.dig("usage", "completion_tokens").to_i
      @input_tokens += input
      @output_tokens += output
      cost = (input * 2.5 / 1_000_000) + (output * 10.0 / 1_000_000)
      puts "🤖 #{show_date} [#{input.to_fs(:delimited)} in / #{output.to_fs(:delimited)} out / $#{format_cost(cost)} / total: $#{format_cost(calculate_cost)}]"
      content = JSON.parse(result["choices"].first["message"]["content"])
      {
        show_notes: content["show_notes"].presence,
        track_notes: content["track_notes"].presence || []
      }
    else
      raise "OpenAI API error: #{response.body}"
    end
  end

  def analyze_with_claude(prompt, show_date)
    response = Typhoeus.post(
      "https://api.anthropic.com/v1/messages",
      headers: {
        "x-api-key" => anthropic_api_token,
        "anthropic-version" => "2023-06-01",
        "Content-Type" => "application/json"
      },
      body: {
        model:,
        max_tokens: 4096,
        system: system_prompt,
        messages: [
          { role: "user", content: prompt }
        ]
      }.to_json
    )

    if response.success?
      result = JSON.parse(response.body)
      input = result.dig("usage", "input_tokens").to_i
      output = result.dig("usage", "output_tokens").to_i
      @input_tokens += input
      @output_tokens += output
      cost = (input * 15.0 / 1_000_000) + (output * 75.0 / 1_000_000)
      puts "🤖 #{show_date} [#{input.to_fs(:delimited)} in / #{output.to_fs(:delimited)} out / $#{format_cost(cost)} / total: $#{format_cost(calculate_cost)}]"
      text = result["content"].first["text"]
      json_match = text.match(/```(?:json)?\s*(.*?)\s*```/m)
      json_str = json_match ? json_match[1] : text
      content = JSON.parse(json_str)
      {
        show_notes: content["show_notes"].presence,
        track_notes: content["track_notes"].presence || []
      }
    else
      raise "Anthropic API error: #{response.body}"
    end
  end

  def system_prompt
    <<~PROMPT
      You are an expert on Phish concerts. Your task is to analyze setlist notes and:
      1. Determine if they describe physical/theatrical elements warranting a "Stage Notes" tag
      2. Extract ONLY the portions describing those theatrical elements - PRESERVE THE ORIGINAL WORDING, do not summarize or paraphrase
      3. Optionally identify song-specific notes that can stand alone

      CRITICAL: Preserve the original wording as much as possible. You may make minor edits to ensure the extracted text reads naturally as a standalone description (e.g., remove orphaned words like "then" at the start of a sentence that no longer makes sense after omissions). Do NOT summarize or condense the content.

      The Stage Notes tag should be applied for:
      - Stage productions or theatrical performances
      - Props, costumes worn by band members, or special stage setups
      - Scripted skits, stories, or narratives performed during the show
      - Unusual visual elements like projections, special lighting effects, or pyrotechnics
      - Interactive audience participation events organized by the band
      - Birthday celebrations, weddings, or other ceremonies on stage
      - Pranks or elaborate jokes performed during the show
      - Unusual circumstances or improvised solutions (e.g., makeshift equipment, notable between-set activities)
      - Interesting non-musical events or anecdotes about the performance environment

      OMIT from extracted notes (these are covered by other tags):
      - Song teases (e.g., "YEM contained Fuego teases")
      - Debut information (e.g., "This show featured the Phish debut of...")
      - Bustout/gap info (e.g., "performed for the first time since X date (N shows)")
      - Segue descriptions
      - Lyrics changes or alternate versions
      - Guest musicians
      - Weather events
      - Brief banter or standard audience interaction
      - Technical issues or audio quality notes (but DO include interesting anecdotes like venue conflicts or unusual circumstances)
      - Setlist structure notes (e.g., "no encore break", "announced as the start of the encore")
      - Solo references (e.g., "Fish took a drum solo", "Trey soloed")
      - Content already captured in existing tags (provided in the prompt) - do NOT duplicate
      - If the SAME CONTENT (even worded differently) appears in an existing tag, do not include it
      - Common tag types and what they cover:
        - Alt Rig: Alternate equipment like megaphones, different guitars, drum kits, etc.
        - Alt Lyric: Alternate or additional lyrics
        - Banter: Verbal interactions, thanks, dedications, announcements
        - Tease: Musical references to other songs
        - Jamcharts: Notable improvisational segments
        - Gamehendge: The Gamehendge musical suite/narration - if this tag exists, Gamehendge content is already covered
        - Costume: Halloween costume sets - if this tag exists, costume-related content is already covered
      - If ALL theatrical content is already covered by existing tags, return null for both show_notes and track_notes

      If an ommission causes the overall note to lack detail, it's okay to duplicate some of these, but such cases should be minimized.

      OUTPUT RULES:
      - show_notes: Use when theatrical content:
        - Spans multiple songs
        - Happens BETWEEN songs or sets (not during any specific track)
        - Describes show setup, equipment, or environment that doesn't belong to a track
        - Provides important show-wide context
        - When show_notes IS warranted, include phrases like "During Fee, Trey used a megaphone" to provide context for track-specific portions.
        - show_notes should be COHERENT and readable as a standalone narrative.
      - track_notes: Use when theatrical content happens DURING a specific song.
        - If content applies to only ONE track and happens DURING that track's performance, return ONLY the track_note with null show_notes - do NOT duplicate at show level.
        - If notes say something spans a RANGE of songs (e.g., "For First Tube through Tweezer Reprise"), create a track_note for EVERY song in that range.
        - If notes say something spans a RANGE of songs (e.g., "For First Tube through Tweezer Reprise"), create a track_note for EVERY song in that range using the provided track listing.
        - The track_note content should be the same as in show_notes, but WITHOUT the "During [song]" prefix.
        - Each track_note must read naturally in isolation. Remove orphaned words like "then" that don't make sense without prior context.
        - Each track note MUST re-introduce any props, costumes, or elements it references.
        - Never use "the" to reference something only defined in show_notes (e.g., "the coils", "the dancers").
        - Do NOT reference the song name, "the song", or "while performing" - the song association is already known from the tag.
        - BAD: "The coils started to descend" (what coils?)
        - BAD: "The dancers sang during the song" (who are "the dancers"?)
        - BAD: "During Tweezer, dancers exited the freezer" (redundant song name)
        - BAD: "Tweezer featured dancers exiting the freezer" (redundant song name)
        - BAD: "Send in the Clowns was sung a cappella" (redundant song name)
        - BAD: "Rocky Top was played for the Drebbers" (redundant song name - transform to track note)
        - BAD: "The song was sung a cappella" (redundant "the song")
        - BAD: "Trey was lifted up while performing the song" (redundant "while performing the song")
        - BAD: "then came onstage appearing as Zamfir" (orphaned "then" - doesn't make sense without prior context)
        - GOOD: "Sung a cappella with lyrics changed to Send in the Clones"
        - GOOD: "Played for the Drebbers, who had just gotten married" (transformed from "[Song] was played for...")
        - GOOD: "Trey and Mike were lifted up in the air as dancers appeared with giant inflatable objects"
        - GOOD: "White coils that had been suspended over the stage began to descend as screens lit up"
        - GOOD: "Dancers dressed as 'conjurors of thunder' with yellow fabric sang along"
        - GOOD: "Dancers from past NYE gags exited the freezer and performed the Meatstick dance"
        - GOOD: "Richard Glasgow (a.k.a. Dickie Scotland) came onstage appearing as Zamfir" (removed orphaned "then")
        - Preserve double quotes from the original notes (escape them properly in JSON as \").
        - Only ONE track_note per song. Do not create multiple entries for the same song.

      Respond with JSON in this exact format:
      {
        "show_notes": "Show-level theatrical description (null if only a single track with brief content)",
        "track_notes": [
          {"song_title": "Song Name", "notes": "Self-contained description of what happened during this song"}
        ]
      }

      IMPORTANT: Only include show_notes when there are multiple theatrical elements OR when context spanning multiple songs is needed. A single track with a brief note should ONLY have a track_note.

      EXAMPLE:
      Input: "YEM contained Fuego teases. Throughout the show, white coils turned while suspended over the stage. During Pillow Jets, the coils descended and dancers came out. The dancers sang during What's Going Through Your Mind. Spock's Brain was performed for the first time since 2019 (238 shows)."

      Output:
      {
        "show_notes": "Throughout the show, white coils turned while suspended over the stage. During Pillow Jets, the coils descended and dancers came out. The dancers sang during What's Going Through Your Mind.",
        "track_notes": [
          {"song_title": "Pillow Jets", "notes": "White coils that had been suspended over the stage descended and dancers came out."},
          {"song_title": "What's Going Through Your Mind", "notes": "Dancers from the Pillow Jets segment sang."}
        ]
      }

      Notice how each track_note re-introduces elements: "White coils that had been suspended" instead of "the coils", and "Dancers from the Pillow Jets segment" instead of "the dancers".

      EXAMPLE 2 (preserving double quotes):
      Input: "Trey introduced Fish as \"The Man Mulcahy.\""

      Output:
      {
        "show_notes": "Trey introduced Fish as \"The Man Mulcahy.\"",
        "track_notes": []
      }

      Notice the double quotes around "The Man Mulcahy" are preserved using JSON escaping (\").

      EXAMPLE 3 (ALL content already covered by existing tags - return null for BOTH):
      Existing tags: Fee [Alt Rig]: Trey on megaphone
      Input: "Fee featured Trey on megaphone."

      Output:
      {
        "show_notes": null,
        "track_notes": []
      }

      The megaphone content is already covered by the Alt Rig tag, so we return null for BOTH.

      EXAMPLE 4 (single track - track_note only, no show_notes regardless of length):
      Input: "During the jam, cartoons were shown behind the band on six television screens. The cartoons got faster and faster while the band did the same."

      Output:
      {
        "show_notes": null,
        "track_notes": [
          {"song_title": "Jam", "notes": "Cartoons were shown behind the band on six television screens. The cartoons got faster and faster while the band did the same."}
        ]
      }

      Even though this is a longer description, it only applies to ONE track (Jam), so we return ONLY the track_note. Adding "During the jam" to show_notes would be redundant since the track association already provides that context.

      EXAMPLE 5 (show-level only - content doesn't belong to any specific track):
      Input: "The band was short on equipment, so a hockey stick was used as a microphone stand. Between sets, the DJ spun some Michael Jackson and Trey drummed along to the album."

      Output:
      {
        "show_notes": "The band was short on equipment, so a hockey stick was used as a microphone stand. Between sets, the DJ spun some Michael Jackson and Trey drummed along to the album.",
        "track_notes": []
      }

      This content describes show setup and between-set activities - it doesn't happen DURING any specific track, so it goes in show_notes only.
    PROMPT
  end

  def build_prompt(notes, track_info, existing_tag_notes)
    tracks_list = track_info.map { |t| "#{t[:set]}: #{t[:title]}" }.join("\n")
    tracks_context = "\n\nSetlist (with set info):\n#{tracks_list}"

    existing_context = ""
    if existing_tag_notes[:show].any? || existing_tag_notes[:tracks].any?
      parts = []
      existing_tag_notes[:show].each do |st|
        parts << if st[:notes]
          "Show [#{st[:tag]}]: #{st[:notes]}"
        else
          "Show [#{st[:tag]}]"
        end
      end
      existing_tag_notes[:tracks].each do |tt|
        parts << if tt[:notes]
          "#{tt[:track]} [#{tt[:tag]}]: #{tt[:notes]}"
        else
          "#{tt[:track]} [#{tt[:tag]}]"
        end
      end
      existing_context = "\n\nExisting tags (DO NOT duplicate or suggest content already covered by these tags):\n#{parts.join("\n")}"
    end

    <<~PROMPT
      Analyze these Phish show setlist notes:

      #{notes}#{tracks_context}#{existing_context}

      Extract theatrical content and categorize it as show-level or track-level.
    PROMPT
  end

  def pnet_api_key
    @pnet_api_key ||= ENV.fetch("PNET_API_KEY")
  end

  def openai_api_token
    @openai_api_token ||= ENV.fetch("OPENAI_API_TOKEN")
  end

  def anthropic_api_token
    @anthropic_api_token ||= ENV.fetch("ANTHROPIC_API_KEY")
  end

  def calculate_cost
    if model.start_with?("claude")
      (@input_tokens * 15.0 / 1_000_000) + (@output_tokens * 75.0 / 1_000_000)
    else
      (@input_tokens * 2.5 / 1_000_000) + (@output_tokens * 10.0 / 1_000_000)
    end
  end

  def format_cost(cost)
    return "0.00" if cost.zero?
    return format("%.2f", cost) if cost >= 0.01
    precision = -Math.log10(cost).floor
    format("%.#{precision}f", cost)
  end
end
