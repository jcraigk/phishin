class StageNotesSyncService < ApplicationService
  option :date, default: -> { nil }
  option :start_date, default: -> { nil }
  option :end_date, default: -> { nil }
  option :all, default: -> { false }
  option :dry_run, default: -> { false }

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

    shows.each do |show|
      process_show(show)
      pbar.increment
    end

    puts "\nComplete!"
    puts "  Shows:  Tagged: #{@show_tagged}, Updated: #{@show_updated}"
    puts "  Tracks: Tagged: #{@track_tagged}, Updated: #{@track_updated}"
    puts "  Skipped: #{@skipped}"
  end

  private

  def validate_options!
    return if date || (start_date && end_date) || all
    raise ArgumentError, "Must specify DATE, START_DATE+END_DATE, or ALL=true"
  end

  def fetch_shows
    scope = if date
      Show.where(date:)
    elsif start_date && end_date
      Show.where(date: start_date..end_date)
    else
      Show.all
    end
    scope.includes(:tracks, :tags).order(date: :asc)
  end

  def process_show(show)
    notes = fetch_setlist_notes(show.date)
    if notes.blank?
      @skipped += 1
      return
    end

    track_info = show.tracks.order(:position).map { |t| { title: t.title, set: t.set_name } }
    existing_tags = show.tags.pluck(:slug)
    analysis = analyze_with_chatgpt(notes, track_info, existing_tags)

    apply_show_tag(show, analysis[:show_notes]) if analysis[:show_notes].present?
    apply_track_tags(show, analysis[:track_notes]) if analysis[:track_notes].present?

    @skipped += 1 if analysis[:show_notes].blank? && analysis[:track_notes].blank?
  rescue StandardError => e
    puts "\n✗ Error processing #{show.date}: #{e.message}"
    @skipped += 1
  end

  def apply_show_tag(show, extracted_notes)
    existing = ShowTag.find_by(show:, tag: @stage_notes_tag)

    if existing
      return if existing.notes == extracted_notes
      unless dry_run
        existing.update!(notes: extracted_notes)
        puts "\n↻ Show updated: #{show.date}"
        puts "  Notes: #{extracted_notes.truncate(100)}"
      else
        puts "\n[DRY RUN] Would update show: #{show.date}"
        puts "  Old: #{existing.notes}"
        puts "  New: #{extracted_notes}"
      end
      @show_updated += 1
    else
      unless dry_run
        ShowTag.create!(show:, tag: @stage_notes_tag, notes: extracted_notes)
        puts "\n✓ Show tagged: #{show.date}"
        puts "  Notes: #{extracted_notes.truncate(100)}"
      else
        puts "\n[DRY RUN] Would tag show: #{show.date}"
        puts "  Notes: #{extracted_notes}"
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
        unless dry_run
          existing.update!(notes:)
          puts "\n↻ Track updated: #{show.date} - #{track.title}"
          puts "  Notes: #{notes.truncate(100)}"
        else
          puts "\n[DRY RUN] Would update track: #{show.date} - #{track.title}"
          puts "  Old: #{existing.notes}"
          puts "  New: #{notes}"
        end
        @track_updated += 1
      else
        unless dry_run
          TrackTag.create!(track:, tag: @stage_notes_tag, notes:)
          puts "\n✓ Track tagged: #{show.date}"
          puts "  Notes: #{notes.truncate(100)}"
        else
          puts "\n[DRY RUN] Would tag track: #{show.date} - #{track.title}"
          puts "  Notes: #{notes}"
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

  def fetch_setlist_notes(show_date)
    url = "https://api.phish.net/v5/shows/showdate/#{show_date}.json?apikey=#{pnet_api_key}"
    response = Typhoeus.get(url)
    return nil unless response.success?

    data = JSON.parse(response.body)
    return nil unless data["data"]&.any?

    data["data"].first["setlist_notes"]
  end

  def analyze_with_chatgpt(notes, track_info, existing_tags)
    prompt = build_prompt(notes, track_info, existing_tags)

    response = Typhoeus.post(
      "https://api.openai.com/v1/chat/completions",
      headers: {
        "Authorization" => "Bearer #{openai_api_token}",
        "Content-Type" => "application/json"
      },
      body: {
        model: "gpt-4o-mini",
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
      content = JSON.parse(result["choices"].first["message"]["content"])
      {
        show_notes: content["show_notes"].presence,
        track_notes: content["track_notes"].presence || []
      }
    else
      raise "ChatGPT API error: #{response.body}"
    end
  end

  def system_prompt
    <<~PROMPT
      You are an expert on Phish concerts. Your task is to analyze setlist notes and:
      1. Determine if they describe physical/theatrical elements warranting a "Stage Notes" tag
      2. Extract ONLY the portions describing those theatrical elements
      3. Optionally identify song-specific notes that can stand alone

      The Stage Notes tag should be applied for:
      - Stage productions or theatrical performances
      - Props, costumes worn by band members, or special stage setups
      - Scripted skits, stories, or narratives performed during the show
      - Unusual visual elements like projections, special lighting effects, or pyrotechnics
      - Interactive audience participation events organized by the band
      - Birthday celebrations, weddings, or other ceremonies on stage
      - Pranks or elaborate jokes performed during the show

      OMIT from extracted notes (these are covered by other tags):
      - Song teases (e.g., "YEM contained Fuego teases")
      - Debut information (e.g., "This show featured the Phish debut of...")
      - Bustout/gap info (e.g., "performed for the first time since X date (N shows)")
      - Segue descriptions
      - Lyrics changes or alternate versions
      - Guest musicians
      - Weather events
      - Brief banter or standard audience interaction
      - Technical issues or audio quality notes

      If an ommission causes the overall note to lack detail, it's okay to duplicate some of these, but such cases should be minimized.

      OUTPUT RULES:
      - show_notes: ALWAYS include the COMPLETE theatrical description here. This is the full narrative of all stage/theatrical elements.
      - track_notes: If theatrical content happens during a SPECIFIC SONG, that song SHOULD get a track_note.
        - Even if it's the only theatrical element in the show, the song still gets a track_note.
        - The track_note content should be the same as in show_notes, but WITHOUT the "During [song]" prefix.
        - Each track note MUST re-introduce any props, costumes, or elements it references.
        - Never use "the" to reference something only defined in show_notes (e.g., "the coils", "the dancers").
        - Do NOT reference the song name, "the song", or "while performing" - the song association is already known from the tag.
        - BAD: "The coils started to descend" (what coils?)
        - BAD: "The dancers sang during the song" (who are "the dancers"?)
        - BAD: "During Tweezer, dancers exited the freezer" (redundant song name)
        - BAD: "Tweezer featured dancers exiting the freezer" (redundant song name)
        - BAD: "Send in the Clowns was sung a cappella" (redundant song name)
        - BAD: "The song was sung a cappella" (redundant "the song")
        - BAD: "Trey was lifted up while performing the song" (redundant "while performing the song")
        - GOOD: "Sung a cappella with lyrics changed to Send in the Clones"
        - GOOD: "Trey and Mike were lifted up in the air as dancers appeared with giant inflatable objects"
        - GOOD: "White coils that had been suspended over the stage began to descend as screens lit up"
        - GOOD: "Dancers dressed as 'conjurors of thunder' with yellow fabric sang along"
        - GOOD: "Dancers from past NYE gags exited the freezer and performed the Meatstick dance"
        - Preserve double quotes from the original notes (escape them properly in JSON as \").
        - Only ONE track_note per song. Do not create multiple entries for the same song.

      Respond with JSON in this exact format:
      {
        "show_notes": "Complete theatrical description for the whole show, or null if none",
        "track_notes": [
          {"song_title": "Song Name", "notes": "Self-contained description of what happened during this song"}
        ]
      }

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
    PROMPT
  end

  def build_prompt(notes, track_info, existing_tags)
    tags_context = existing_tags.any? ? "\n\nExisting tags: #{existing_tags.join(', ')}" : ""
    tracks_list = track_info.map { |t| "#{t[:set]}: #{t[:title]}" }.join("\n")
    tracks_context = "\n\nSetlist (with set info):\n#{tracks_list}"

    <<~PROMPT
      Analyze these Phish show setlist notes:

      #{notes}#{tracks_context}#{tags_context}

      Extract theatrical content and categorize it as show-level or track-level.
    PROMPT
  end

  def pnet_api_key
    @pnet_api_key ||= ENV.fetch("PNET_API_KEY")
  end

  def openai_api_token
    @openai_api_token ||= ENV.fetch("OPENAI_API_TOKEN")
  end
end
