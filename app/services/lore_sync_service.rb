class LoreSyncService < ApplicationService
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
  option :delay, default: -> { 0 }

  def call
    validate_options!
    @lore_tag = Tag.find_by!(slug: "lore")
    @banter_tag = Tag.find_by!(slug: "banter")
    @alt_rig_tag = Tag.find_by!(slug: "alt-rig")
    @alt_lyric_tag = Tag.find_by!(slug: "alt-lyric")
    @a_cappella_tag = Tag.find_by!(slug: "a-cappella")
    @acoustic_tag = Tag.find_by!(slug: "acoustic")
    @unfinished_tag = Tag.find_by!(slug: "unfinished")
    shows = fetch_shows

    puts "Analyzing #{shows.count} show(s)#{dry_run ? ' (DRY RUN)' : ''}..."
    @pbar = ProgressBar.create(total: shows.count, format: "%a %B %c/%C %p%% %E")

    @show_tagged = 0
    @show_updated = 0
    @track_tagged = 0
    @track_updated = 0
    @skipped = 0
    @input_tokens = 0
    @output_tokens = 0

    shows.each_with_index do |show, index|
      process_show(show)
      @pbar.increment
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

    # Handle show-level tags
    lore_show = analysis[:lore_show].presence
    banter_show = analysis[:banter_show].presence

    apply_show_tag(show, normalize_quotes(lore_show), @lore_tag, "Lore") if lore_show.present?
    apply_show_tag(show, normalize_quotes(banter_show), @banter_tag, "Banter") if banter_show.present?

    # Handle track-level tags
    lore_tracks = (analysis[:lore_tracks].presence || [])
      .reject { |tn| tn["song_title"].downcase == "banter" }
      .each { |tn| tn["notes"] = normalize_quotes(tn["notes"]) }
    banter_tracks = (analysis[:banter_tracks].presence || [])
      .reject { |tn| tn["song_title"].downcase == "banter" }
      .each { |tn| tn["notes"] = normalize_quotes(tn["notes"]) }
    alt_rig_tracks = (analysis[:alt_rig_tracks].presence || [])
      .reject { |tn| tn["song_title"].downcase == "banter" }
      .each { |tn| tn["notes"] = normalize_quotes(tn["notes"]) }
    alt_lyric_tracks = (analysis[:alt_lyric_tracks].presence || [])
      .reject { |tn| tn["song_title"].downcase == "banter" }
      .each { |tn| tn["notes"] = normalize_quotes(tn["notes"]) }
    a_cappella_tracks = (analysis[:a_cappella_tracks].presence || [])
      .reject { |tn| tn["song_title"].downcase == "banter" }
      .each { |tn| tn["notes"] = nil }
    acoustic_tracks = (analysis[:acoustic_tracks].presence || [])
      .reject { |tn| tn["song_title"].downcase == "banter" }
      .each { |tn| tn["notes"] = nil }
    unfinished_tracks = (analysis[:unfinished_tracks].presence || [])
      .reject { |tn| tn["song_title"].downcase == "banter" }
      .each { |tn| tn["notes"] = normalize_quotes(tn["notes"]) }

    apply_track_tags(show, lore_tracks, @lore_tag, "Lore") if lore_tracks.any?
    apply_track_tags(show, banter_tracks, @banter_tag, "Banter") if banter_tracks.any?
    apply_track_tags(show, alt_rig_tracks, @alt_rig_tag, "Alt Rig") if alt_rig_tracks.any?
    apply_track_tags(show, alt_lyric_tracks, @alt_lyric_tag, "Alt Lyric") if alt_lyric_tracks.any?
    apply_track_tags(show, a_cappella_tracks, @a_cappella_tag, "A Cappella") if a_cappella_tracks.any?
    apply_track_tags(show, acoustic_tracks, @acoustic_tag, "Acoustic") if acoustic_tracks.any?
    apply_track_tags(show, unfinished_tracks, @unfinished_tag, "Unfinished") if unfinished_tracks.any?

    @skipped += 1 if lore_show.blank? && banter_show.blank? && lore_tracks.empty? && banter_tracks.empty? && alt_rig_tracks.empty? && alt_lyric_tracks.empty? && a_cappella_tracks.empty? && acoustic_tracks.empty? && unfinished_tracks.empty?
  rescue StandardError => e
    @pbar.log "✗ Error processing #{show.date}: #{e.message}"
    @skipped += 1
  end

  def apply_show_tag(show, extracted_notes, tag, tag_name)
    existing = ShowTag.find_by(show:, tag:)
    show_url = "https://phish.in/#{show.date}"
    colored_tag = colorize(tag_name, tag.color)

    if existing
      return if existing.notes == extracted_notes
      if dry_run
        @pbar.log "🏟️ [DRY RUN] Would update show #{colored_tag}: #{show_url}\n  Old: \e[36m#{existing.notes}\e[0m\n  New: \e[36m#{extracted_notes}\e[0m"
      else
        existing.update!(notes: extracted_notes)
        @pbar.log "🏟️ Show #{colored_tag} updated: #{show_url}#{verbose ? "\n  \e[36m#{extracted_notes}\e[0m" : ""}"
      end
      @show_updated += 1
    else
      if dry_run
        @pbar.log "🏟️ [DRY RUN] Would tag show #{colored_tag}: #{show_url}\n  \e[36m#{extracted_notes}\e[0m"
      else
        ShowTag.create!(show:, tag:, notes: extracted_notes)
        @pbar.log "🏟️ Show #{colored_tag} tagged: #{show_url}#{verbose ? "\n  \e[36m#{extracted_notes}\e[0m" : ""}"
      end
      @show_tagged += 1
    end
  end

  def apply_track_tags(show, track_notes, tag, tag_name)
    track_notes = track_notes.uniq { |tn| tn["song_title"] }
    colored_tag = colorize(tag_name, tag.color)
    track_notes.each do |track_note|
      track = find_track(show, track_note["song_title"])
      next unless track

      existing = TrackTag.find_by(track:, tag:)
      notes = track_note["notes"]

      track_url = "https://phish.in/#{show.date}/#{track.slug}"

      if existing
        next if existing.notes == notes
        if dry_run
          @pbar.log "🎸 [DRY RUN] Would update track #{colored_tag}: #{track_url}\n  Old: \e[36m#{existing.notes}\e[0m\n  New: \e[36m#{notes}\e[0m"
        else
          existing.update!(notes:)
          @pbar.log "🎸 Track #{colored_tag} updated: #{track_url}#{verbose && notes.present? ? "\n  \e[36m#{notes}\e[0m" : ""}"
        end
        @track_updated += 1
      else
        if dry_run
          @pbar.log "🎸 [DRY RUN] Would tag track #{colored_tag}: #{track_url}\n  \e[36m#{notes}\e[0m"
        else
          TrackTag.create!(track:, tag:, notes:)
          @pbar.log "🎸 Track #{colored_tag} tagged: #{track_url}#{verbose && notes.present? ? "\n  \e[36m#{notes}\e[0m" : ""}"
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

    normalize_quotes(data["data"].first["setlist_notes"])
  end

  def normalize_quotes(text)
    return nil if text.nil?
    text
      .gsub(/[“”]/, '"')
      .gsub(/[‘’]/, "'")
      .gsub(/<[^>]+>/, "")
      .then { |t| CGI.unescapeHTML(t) }
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
      @pbar.log "🤖 #{show_date} [#{input.to_fs(:delimited)} in / #{output.to_fs(:delimited)} out / $#{format_cost(cost)} / total: $#{format_cost(calculate_cost)}]"
      content = JSON.parse(result["choices"].first["message"]["content"])
      {
        lore_show: content["lore_show"].presence,
        lore_tracks: content["lore_tracks"].presence || [],
        banter_show: content["banter_show"].presence,
        banter_tracks: content["banter_tracks"].presence || [],
        alt_rig_tracks: content["alt_rig_tracks"].presence || [],
        alt_lyric_tracks: content["alt_lyric_tracks"].presence || [],
        a_cappella_tracks: content["a_cappella_tracks"].presence || [],
        acoustic_tracks: content["acoustic_tracks"].presence || [],
        unfinished_tracks: content["unfinished_tracks"].presence || []
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
      @pbar.log "🤖 #{show_date} [#{input.to_fs(:delimited)} in / #{output.to_fs(:delimited)} out / $#{format_cost(cost)} / total: $#{format_cost(calculate_cost)}]"
      text = result["content"].first["text"]
      json_match = text.match(/```(?:json)?\s*(.*?)\s*```/m)
      json_str = json_match ? json_match[1] : text
      content = JSON.parse(json_str)
      {
        lore_show: content["lore_show"].presence,
        lore_tracks: content["lore_tracks"].presence || [],
        banter_show: content["banter_show"].presence,
        banter_tracks: content["banter_tracks"].presence || [],
        alt_rig_tracks: content["alt_rig_tracks"].presence || [],
        alt_lyric_tracks: content["alt_lyric_tracks"].presence || [],
        a_cappella_tracks: content["a_cappella_tracks"].presence || [],
        acoustic_tracks: content["acoustic_tracks"].presence || [],
        unfinished_tracks: content["unfinished_tracks"].presence || []
      }
    else
      raise "Anthropic API error: #{response.body}"
    end
  end

  def system_prompt
    <<~PROMPT
      You are an expert on Phish concerts. Your task is to analyze setlist notes and:
      1. Determine if they describe physical/theatrical elements warranting a "Lore" tag
      2. Extract ONLY the portions describing those theatrical elements - PRESERVE THE ORIGINAL WORDING, do not summarize or paraphrase
      3. Optionally identify song-specific notes that can stand alone

      CRITICAL: Preserve the original wording as much as possible. You may make minor edits to ensure the extracted text reads naturally as a standalone description (e.g., remove orphaned words like "then" at the start of a sentence that no longer makes sense after omissions). Do NOT summarize or condense the content.

      CRITICAL: When notes contain BOTH content to omit (like teases) AND content to include (like giveaways), you MUST still extract the includable content. Do not skip the entire note just because part of it should be omitted.

      FORMATTING: Convert single quotes used as quotation marks to double quotes (e.g., 'Blackwood Convention' becomes "Blackwood Convention"). Keep apostrophes in contractions as single quotes (e.g., "band's", "wasn't").

      The Lore tag should be applied for:
      - Stage productions or theatrical performances
      - Props, costumes worn by band members, or special stage setups
      - Scripted skits, stories, or narratives performed during the show
      - Unusual visual elements like projections, special lighting effects, or pyrotechnics
      - Interactive audience participation events organized by the band
      - Birthday celebrations, weddings, or other ceremonies on stage
      - Pranks or elaborate jokes performed during the show
      - Unusual circumstances or improvised solutions (e.g., makeshift equipment, notable between-set activities)
      - Unusual giveaways of significant items (e.g., giving away the band's van, a car, Fish's vacuum, or any vehicle/valuable item to a fan - these are RARE and MEMORABLE events)
      - Interesting non-musical events that fans would find memorable

      ALWAYS OMIT these (handled by separate tag systems, regardless of whether tags exist):
      - Song teases (e.g., "YEM contained Fuego teases", "Page teased Speed Racer", "Page teased Charge!")
      - Debut information (e.g., "This show featured the Phish debut of...")
      - Bustout/gap info (e.g., "performed for the first time since X date (N shows)")
      - Segue descriptions
      - Guest musicians
      - Weather events
      - Technical issues or audio quality notes
      - Setlist structure notes (e.g., "no encore break", "announced as the start of the encore")
      - Routine dedications without interesting context (e.g., "Dedicated to Brad Sands", "played for mom")
      - Simple birthday wishes without ceremony (e.g., "Trey wished happy birthday to Jim")
      - Microphone/amplification usage or lack thereof (e.g., "sung without microphones", "performed without amplification", "performed unplugged")
      - Acoustic performances (handled by Acoustic tag)

      ALWAYS INCLUDE (even if mixed with content you'd normally omit):
      - Giving away vehicles or valuable items to fans (e.g., "Fish's minivan was given away" - MAJOR event!)
      - Weddings, anniversaries, or ceremonies where the band performs a role
      - Costume contests, unusual competitions, or fan participation events
      - Pranks, elaborate jokes, or unusual stage antics

      OMIT ONLY THE SPECIFIC CONTENT already covered by an existing tag:
      - If an existing tag covers a tease, omit the tease portion but KEEP other content
      - If an existing tag covers banter, omit that banter but KEEP other content
      - Only omit the exact content that's duplicated - not the entire note
      - Common tag types: Alt Rig, Alt Lyric, Banter, Tease, Jamcharts, Gamehendge, Costume, A Cappella, Acoustic, Unfinished
      - EXCEPTION: If an existing Lore tag exists at the SHOW level but describes song-specific content, you SHOULD still output track_notes for that content.

      ONLY return null for both show_notes and track_notes if EVERY piece of content either falls into "ALWAYS OMIT" categories OR is covered by existing tags. If ANY Lore-worthy content remains after filtering, include it.

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
        "lore_show": "Show-level Lore description (null if none)",
        "lore_tracks": [
          {"song_title": "Song Name", "notes": "Lore content for this song"}
        ],
        "banter_show": null,
        "banter_tracks": [
          {"song_title": "Song Name", "notes": "Banter content for this song"}
        ],
        "alt_rig_tracks": [
          {"song_title": "Song Name", "notes": "Alt Rig content for this song"}
        ],
        "alt_lyric_tracks": [
          {"song_title": "Song Name", "notes": "Alt Lyric content for this song"}
        ],
        "a_cappella_tracks": [
          {"song_title": "Song Name", "notes": null}
        ],
        "acoustic_tracks": [
          {"song_title": "Song Name", "notes": null}
        ],
        "unfinished_tracks": [
          {"song_title": "Song Name", "notes": "Description of what was unfinished (optional)"}
        ]
      }

      CATEGORIZATION RULES (MUTUALLY EXCLUSIVE - each piece of content goes in ONE category only):
      - LORE: Stage productions, props, costumes, theatrical elements, unusual giveaways, ceremonies, pranks, visual effects, historically significant context about milestone shows. NOT for lyric changes, instrument changes, or verbal banter.
      - BANTER: Verbal introductions, nicknames, dedications, thank-yous, jokes between band members, announcements (TRACK-LEVEL ONLY - banter_show must always be null)
      - ALT RIG: Band members playing non-standard instruments or equipment (e.g., Fish on washboard, Trey on marimba, acoustic instruments when unusual) (TRACK-LEVEL ONLY)
      - ALT LYRIC: Modified, alternate, or improvised lyrics (e.g., changed words, personalized verses, humorous substitutions) (TRACK-LEVEL ONLY). If lyrics were changed, this is the ONLY tag to use - never also Lore.
      - A CAPPELLA: Sung a cappella, meaning vocals without instrumental accompaniment (TRACK-LEVEL ONLY)
      - ACOUSTIC: Performed on acoustic instruments (TRACK-LEVEL ONLY)
      - UNFINISHED: Song performed incompletely, missing verses, sections, or cut short (TRACK-LEVEL ONLY)

      CRITICAL: Before creating a track entry, check if the song exists in the provided setlist. If a song mentioned in the notes is NOT in the setlist, put the content in the show-level field instead.

      IMPORTANT: Only include show-level notes when content spans multiple songs, happens between songs, OR when the referenced song is not in the setlist.

      EXAMPLE 1 (theatrical Lore with track-level content):
      Input: "Throughout the show, white coils turned while suspended over the stage. During Pillow Jets, the coils descended and dancers came out."

      Output:
      {
        "lore_show": "Throughout the show, white coils turned while suspended over the stage. During Pillow Jets, the coils descended and dancers came out.",
        "lore_tracks": [
          {"song_title": "Pillow Jets", "notes": "White coils that had been suspended over the stage descended and dancers came out."}
        ],
        "banter_show": null,
        "banter_tracks": []
      }

      EXAMPLE 2 (Banter - Fish nickname):
      Input: "Before Hold Your Head Up, Trey introduced Fish as \"Captain Zero.\""

      Output:
      {
        "lore_show": null,
        "lore_tracks": [],
        "banter_show": null,
        "banter_tracks": [
          {"song_title": "Hold Your Head Up", "notes": "Trey introduced Fish as \"Captain Zero.\""}
        ]
      }

      Fish introductions/nicknames are BANTER, not Lore.

      EXAMPLE 3 (Lore - unusual giveaway, song not in setlist):
      Existing tags: McGrupp [Tease]: Theme from Jeopardy! by Merv Griffin
      Setlist: My Sweet One, McGrupp, Reba, Stash, Mike's Song, Weekapaug Groove (note: NO "I Didn't Know")
      Input: "McGrupp featured a Jeopardy! theme tease from Page. During I Didn't Know, Fish's family minivan that the band had been traveling in was given away to a fan in the audience."

      Output:
      {
        "lore_show": "During I Didn't Know, Fish's family minivan that the band had been traveling in was given away to a fan in the audience.",
        "lore_tracks": [],
        "banter_show": null,
        "banter_tracks": []
      }

      IMPORTANT: The tease is covered by existing Tease tag. "I Didn't Know" is NOT in the provided setlist, so the minivan content goes in lore_show (not lore_tracks). The minivan is LORE - a major memorable event.

      EXAMPLE 4 (mixed Lore and Banter):
      Input: "Trey ran around the stage with a megaphone during Antelope. During Catapult, Fish took a verbal jab at Trey about his upcoming wedding."

      Output:
      {
        "lore_show": null,
        "lore_tracks": [
          {"song_title": "Run Like an Antelope", "notes": "Trey ran around the stage with a megaphone."}
        ],
        "banter_show": null,
        "banter_tracks": [
          {"song_title": "Catapult", "notes": "Fish took a verbal jab at Trey about his upcoming wedding."}
        ]
      }

      Megaphone usage is LORE (theatrical prop). Wedding jab is BANTER (verbal joke).

      EXAMPLE 5 (all content covered by existing tags):
      Existing tags: Catapult [Jamcharts]: Humorous version with wedding banter
      Input: "During Catapult, Fish took a verbal jab at Trey about his wedding."

      Output:
      {
        "lore_show": null,
        "lore_tracks": [],
        "banter_show": null,
        "banter_tracks": []
      }

      The wedding banter is already mentioned in the Jamcharts tag, so we don't duplicate it.

      EXAMPLE 6 (single track content - track only, NO show duplication):
      Input: "During the jam, cartoons were shown behind the band on six television screens. The cartoons got faster and faster while the band did the same."

      Output:
      {
        "lore_show": null,
        "lore_tracks": [
          {"song_title": "Jam", "notes": "Cartoons were shown behind the band on six television screens. The cartoons got faster and faster while the band did the same."}
        ],
        "banter_show": null,
        "banter_tracks": []
      }

      CRITICAL: This content only applies to ONE track (Jam). Do NOT duplicate it at show level. When content is track-specific, only populate the track array.

      COMMON MISTAKES TO AVOID:
      - WRONG: Duplicating single-track content at both show and track level
        Input: "Before Sleeping Monkey, Trey pulled a woman from the crowd; the band then played the song for her."
        BAD output: lore_show: "Before Sleeping Monkey, Trey pulled a woman from the crowd..." AND lore_tracks: [{"song_title": "Sleeping Monkey", "notes": "..."}]
        CORRECT output: lore_show: null, lore_tracks: [{"song_title": "Sleeping Monkey", "notes": "Trey pulled a woman from the crowd; the band then played the song for her."}]
        REASON: This content applies to ONE track only. Keep the track tag, discard the show tag.
      - WRONG: Duplicating content across multiple tag categories
        Input: "Trey added 'from Goddard College' after the final 'cause I got a degree' lyric."
        BAD output: lore_tracks: [{"song_title": "Alumni Blues", "notes": "..."}] AND alt_lyric_tracks: [{"song_title": "Alumni Blues", "notes": "..."}]
        CORRECT output: alt_lyric_tracks: [{"song_title": "Alumni Blues", "notes": "Trey added 'from Goddard College' after the final 'cause I got a degree' lyric."}]
        REASON: This is a lyric change, so it belongs ONLY in Alt Lyric. Do NOT also tag as Lore. Each piece of content belongs to exactly ONE category.
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

  def colorize(text, hex_color)
    return text unless hex_color&.start_with?("#")
    r, g, b = hex_color[1..6].scan(/../).map { |c| c.to_i(16) }
    "\e[38;2;#{r};#{g};#{b}m#{text}\e[0m"
  end
end
