class StageNotesSyncService < ApplicationService
  option :date, default: -> { nil }
  option :start_date, default: -> { nil }
  option :end_date, default: -> { nil }
  option :all, default: -> { false }
  option :dry_run, default: -> { false }

  def call
    validate_options!
    stage_notes_tag = Tag.find_by!(slug: "stage-notes")
    shows = fetch_shows

    puts "Analyzing #{shows.count} show(s)#{dry_run ? ' (DRY RUN)' : ''}..."
    pbar = ProgressBar.create(total: shows.count, format: "%a %B %c/%C %p%% %E")

    tagged_count = 0
    skipped_count = 0

    shows.each do |show|
      result = process_show(show, stage_notes_tag)
      case result
      when :tagged then tagged_count += 1
      when :skipped then skipped_count += 1
      end
      pbar.increment
    end

    puts "\nComplete! Tagged: #{tagged_count}, Skipped: #{skipped_count}"
  end

  private

  def validate_options!
    return if date || (start_date && end_date) || all
    raise ArgumentError, "Must specify DATE, START_DATE+END_DATE, or ALL=true"
  end

  def fetch_shows
    if date
      Show.where(date:)
    elsif start_date && end_date
      Show.where(date: start_date..end_date)
    else
      Show.all
    end.order(date: :asc)
  end

  def process_show(show, stage_notes_tag)
    return :skipped if show.tags.include?(stage_notes_tag)

    notes = fetch_setlist_notes(show.date)
    return :skipped if notes.blank?

    existing_tags = show.tags.pluck(:slug)
    should_tag = analyze_with_chatgpt(notes, existing_tags)

    if should_tag
      unless dry_run
        show.tags << stage_notes_tag
        puts "\n✓ Tagged: #{show.date} - #{show.venue_name}"
      else
        puts "\n[DRY RUN] Would tag: #{show.date} - #{show.venue_name}"
      end
      :tagged
    else
      :skipped
    end
  rescue StandardError => e
    puts "\n✗ Error processing #{show.date}: #{e.message}"
    :skipped
  end

  def fetch_setlist_notes(show_date)
    url = "https://api.phish.net/v5/shows/showdate/#{show_date}.json?apikey=#{pnet_api_key}"
    response = Typhoeus.get(url)
    return nil unless response.success?

    data = JSON.parse(response.body)
    return nil unless data["data"]&.any?

    data["data"].first["setlist_notes"]
  end

  def analyze_with_chatgpt(notes, existing_tags)
    prompt = build_prompt(notes, existing_tags)

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
        temperature: 0.1
      }.to_json
    )

    if response.success?
      result = JSON.parse(response.body)
      answer = result["choices"].first["message"]["content"].strip.downcase
      answer.start_with?("yes")
    else
      raise "ChatGPT API error: #{response.body}"
    end
  end

  def system_prompt
    <<~PROMPT
      You are an expert on Phish concerts. Your task is to determine if a show's setlist notes describe theatrical elements that warrant a "Stage Notes" tag.

      The Stage Notes tag should be applied for:
      - Stage productions or theatrical performances
      - Props, costumes worn by band members, or special stage setups
      - Scripted skits, stories, or narratives performed during the show
      - Unusual visual elements like projections, special lighting effects, or pyrotechnics
      - Interactive audience participation events organized by the band
      - Birthday celebrations, weddings, or other ceremonies on stage
      - Pranks or elaborate jokes performed during the show

      The Stage Notes tag should NOT be applied for:
      - Musical elements like teases, jams, segues, or song debuts
      - Lyrics changes or alternate versions
      - Guest musicians
      - Weather events
      - Album/song covers (e.g., Halloween "musical costumes")
      - Brief banter or standard audience interaction
      - Technical issues or audio quality notes

      Answer with ONLY "yes" or "no" followed by a brief explanation.
    PROMPT
  end

  def build_prompt(notes, existing_tags)
    tags_context = if existing_tags.any?
      "\n\nExisting tags for this show: #{existing_tags.join(', ')}"
    else
      ""
    end

    <<~PROMPT
      Analyze these Phish show setlist notes and determine if they describe theatrical elements that warrant a "Stage Notes" tag:

      #{notes}#{tags_context}

      Should this show receive the Stage Notes tag?
    PROMPT
  end

  def pnet_api_key
    @pnet_api_key ||= ENV.fetch("PNET_API_KEY")
  end

  def openai_api_token
    @openai_api_token ||= ENV.fetch("OPENAI_API_TOKEN")
  end
end
