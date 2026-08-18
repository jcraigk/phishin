class TeaseSyncService < ApplicationService
  SHEET_RANGE = "Tease!A1:G5000".freeze
  APPEND_RANGE = "Tease!A:F".freeze
  DEV_NOTE = "Imported from Phish.net setlist notes".freeze
  SONG_ALIASES = {
    "2001" => "Also Sprach Zarathustra"
  }.freeze

  option :date, default: -> { nil }
  option :dates, default: -> { nil }
  option :start_date, default: -> { nil }
  option :end_date, default: -> { nil }
  option :all, default: -> { false }
  option :apply, default: -> { false }
  option :verbose, default: -> { false }
  option :model, default: -> { "claude-opus-5" }
  option :delay, default: -> { 0 }

  attr_reader :proposed_rows, :unmatched, :unconfirmed, :unverified_artists

  def call
    validate_options!

    @proposed_rows = []
    @unmatched = []
    @unconfirmed = []
    @unverified_artists = []
    @skipped = 0
    @input_tokens = 0
    @output_tokens = 0
    @existing = load_existing_rows

    shows = fetch_shows
    puts "Analyzing #{shows.count} show(s)#{apply ? '' : ' (DRY RUN)'}..."
    @pbar = ProgressBar.create(total: shows.count, format: "%a %B %c/%C %p%% %E")

    shows.each_with_index do |show, index|
      process_show(show)
      @pbar.increment
      sleep(delay) if delay.positive? && index < shows.size - 1
    end

    print_summary
    append_rows if apply && proposed_rows.any?
  end

  private

  def validate_options!
    return if date || dates || start_date || end_date || all
    raise ArgumentError, "Must specify DATE, DATES, START_DATE, END_DATE, or ALL=true"
  end

  def fetch_shows
    scope =
      if date
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
    scope.includes(:tracks).order(date: :asc)
  end

  def load_existing_rows
    GoogleSpreadsheetFetcher.call(sheet_id, SHEET_RANGE, headers: true)
      .each_with_object(Hash.new { |h, k| h[k] = [] }) do |row, hash|
        key = track_key(row["URL"])
        next if key.blank?
        original = row["Notes"].to_s.strip
        hash[key] << { original:, normalized: normalize(original) }
      end
  end

  def process_show(show)
    notes = fetch_setlist_notes(show.date)
    return @skipped += 1 if notes.blank? || !notes.match?(/teas/i)

    teases = analyze_with_claude(notes, show)
    teases.reject { |tease| tease["in_sheet"] }.each { |tease| evaluate_tease(show, tease) }
    record_unconfirmed(show, teases)
  end

  # Sheet rows for a scanned show that the notes never mention. Not errors --
  # taper-sourced and Tease Chart rows legitimately never appear in setlist notes --
  # but worth surfacing so they can be spot-checked.
  def record_unconfirmed(show, teases)
    found = teases.filter_map { |tease| normalize(tease["tease"].to_s).presence }

    @existing.each do |key, notes|
      next unless key.start_with?("#{show.date}/")
      notes.each do |note|
        title = tease_title(note[:normalized])
        next if title.blank?
        next if found.any? { |f| f.include?(title) || title.include?(f) }
        @unconfirmed << "#{show.date}/#{key.split('/').last} - #{note[:original]}"
      end
    end
  end

  def evaluate_tease(show, tease)
    title = tease["tease"].to_s.strip
    return if title.blank?

    song = tease["song"].to_s.strip
    track = find_track(show, SONG_ALIASES.fetch(song, song))
    return @unmatched << "#{show.date}: #{song} (#{title})" if track.blank?

    note = format_note(title, resolve_artist(title, tease["artist"]))
    return log("  skip (already tagged): #{track.title} - #{note}") if already_covered?(track, note)

    log("  propose: #{track.title} - #{note}")
    @proposed_rows << [ sheet_url(track), "", "", note, "", DEV_NOTE ]
  end

  # Phish.net's song catalog is authoritative for original artist; the model's
  # own guess is a fallback and gets flagged so it can be spot-checked.
  def resolve_artist(title, model_artist)
    known = pnet_artists[normalize(title)]
    return nil if known == "Phish"
    return known if known.present?

    @unverified_artists << "#{title} by #{model_artist}" if model_artist.present?
    model_artist
  end

  def pnet_artists
    @pnet_artists ||= begin
      response = Typhoeus.get("https://api.phish.net/v5/songs.json?apikey=#{pnet_api_key}")
      raise "Phish.net songs API error: #{response.body}" unless response.success?

      JSON.parse(response.body)["data"].to_h do |song|
        [ normalize(song["song"].to_s), song["artist"].to_s.presence ]
      end
    end
  end

  def format_note(title, artist)
    artist = artist.to_s.strip
    normalize_quotes(artist.present? ? "#{title} by #{artist}" : title)
  end

  def already_covered?(track, note)
    existing = @existing[track_key(track.url)]
    return false if existing.blank?

    candidate = normalize(note)
    title = tease_title(candidate)
    existing.any? do |existing_note|
      normalized = existing_note[:normalized]
      normalized == candidate ||
        normalized.include?(title) ||
        title.include?(tease_title(normalized))
    end
  end

  # The sheet is keyed by production URLs, so never write a local/ngrok host into it.
  def sheet_url(track)
    "#{Rails.configuration.production_base_url}/#{track.show.date}/#{track.slug}"
  end

  # Sheet URLs use the production host; Track#url uses the configured host.
  # Key on the date/slug path so lookups match in every environment.
  def track_key(url)
    return nil if url.blank?
    segments = URI.parse(url.strip).path.split("/")
    return nil if segments.size < 2
    segments.last(2).join("/")
  rescue URI::InvalidURIError
    nil
  end

  def tease_title(note)
    note.split(" by ").first.to_s.strip
  end

  def normalize(str)
    normalize_quotes(str).to_s.downcase.gsub(/[[:punct:]]/, "").squish
  end

  def find_track(show, song_title)
    show.tracks.find { |t| t.title.casecmp?(song_title) } ||
      show.tracks.find { |t| t.title.downcase.include?(song_title.downcase) } ||
      show.tracks.find { |t| song_title.downcase.include?(t.title.downcase) }
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

  def analyze_with_claude(notes, show)
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
        messages: [ { role: "user", content: build_prompt(notes, show) } ]
      }.to_json
    )
    raise "Anthropic API error: #{response.body}" unless response.success?

    parse_response(JSON.parse(response.body), show.date)
  end

  def parse_response(result, show_date)
    input = result.dig("usage", "input_tokens").to_i
    output = result.dig("usage", "output_tokens").to_i
    @input_tokens += input
    @output_tokens += output
    log_usage(show_date, input, output)

    # Thinking models emit a thinking block before the text block, so select by type.
    text = result["content"].find { |block| block["type"] == "text" }&.dig("text")
    raise "No text block in Anthropic response: #{result['content'].inspect}" if text.blank?

    json_match = text.match(/```(?:json)?\s*(.*?)\s*```/m)
    JSON.parse(json_match ? json_match[1] : text)["teases"] || []
  end

  def log_usage(show_date, input, output)
    cost = token_cost(input, output)
    log(
      "🤖 #{show_date} [#{input.to_fs(:delimited)} in / #{output.to_fs(:delimited)} out / " \
      "$#{format_cost(cost)} / total: $#{format_cost(total_cost)}]"
    )
  end

  def system_prompt
    <<~PROMPT
      You extract song teases from Phish.net setlist notes.

      A tease is a brief musical quotation of another song played within a performed song.
      Do NOT extract: full cover performances, jams merely "in the style of" something,
      signals, stage banter, gags, props, guest appearances, or debuts.

      Respond with strict JSON only, no prose and no code fence:
      {"teases": [{"song": "<performed song>", "tease": "<teased song title>", "artist": "<original artist or null>", "in_sheet": <true|false>}]}

      Rules:
      - "song" must be the song the tease occurred in, matching a title from the provided setlist when possible.
      - "artist" is the original artist of the teased song. Use null when the teased song is a
        Phish original. Take it from a parenthetical in the notes when present; otherwise give
        your best guess (it is verified against Phish.net's song catalog afterward).
      - List EVERY tease the notes describe, including ones already present in the
        "Existing tease rows" section. Mark each with "in_sheet": true when it matches an
        existing row (comparing on the teased song title, ignoring an omitted "by Artist"
        suffix and punctuation differences) and false otherwise.
      - Handle phrasings such as: "X contained Y teases", "X contained Y and Z teases",
        "Trey teased Y in X, Z in W, and Q in V", "a Y tease in X", "X included a Y tease from Page",
        "Y (Artist) tease".
      - Return {"teases": []} when the notes contain no teases.
    PROMPT
  end

  def build_prompt(notes, show)
    <<~PROMPT
      Show date: #{show.date}

      Setlist:
      #{show.tracks.sort_by(&:position).map(&:title).join("\n")}

      Existing tease rows:
      #{existing_rows_for(show).presence || 'none'}

      Setlist notes:
      #{notes}
    PROMPT
  end

  def existing_rows_for(show)
    @existing
      .select { |key, _| key.start_with?("#{show.date}/") }
      .flat_map { |key, notes| notes.map { |note| "#{key.split('/').last}: #{note[:original]}" } }
      .join("\n")
  end

  def append_rows
    GoogleSpreadsheetAppender.call(sheet_id, APPEND_RANGE, proposed_rows)
    puts "Appended #{proposed_rows.size} row(s). Run `bin/rails tagin:sync` to pull them into the database."
  end

  def print_summary
    puts "\nProposed rows: #{proposed_rows.size}"
    proposed_rows.each { |row| puts "  #{row[0]} - #{row[3]}" }

    if unmatched.any?
      puts "\nUnmatched songs (no track found):"
      unmatched.each { |entry| puts "  #{entry}" }
    end

    if unverified_artists.any?
      puts "\nArtist not in the Phish.net song catalog (#{unverified_artists.size}) - verify before applying:"
      unverified_artists.uniq.each { |entry| puts "  #{entry}" }
    end

    if unconfirmed.any?
      puts "\nIn sheet but not in Phish.net notes (#{unconfirmed.size}) - review, not necessarily wrong:"
      unconfirmed.each { |entry| puts "  #{entry}" }
    end

    puts "\nSkipped shows (no notes or no teases): #{@skipped}"
    puts "Tokens: #{@input_tokens.to_fs(:delimited)} input, #{@output_tokens.to_fs(:delimited)} output"
    puts "Cost:   $#{format_cost(total_cost)}"
    puts "\nDry run. Re-run with APPLY=true to append these rows." if !apply && proposed_rows.any?
  end

  def token_cost(input, output)
    (input * 5.0 / 1_000_000) + (output * 25.0 / 1_000_000)
  end

  def total_cost
    token_cost(@input_tokens, @output_tokens)
  end

  def format_cost(cost)
    format("%.4f", cost)
  end

  def log(message)
    return unless verbose
    @pbar ? @pbar.log(message) : puts(message)
  end

  def sheet_id
    @sheet_id ||= ENV.fetch("TAGIN_GSHEET_ID")
  end

  def pnet_api_key
    @pnet_api_key ||= ENV.fetch("PNET_API_KEY")
  end

  def anthropic_api_token
    @anthropic_api_token ||= ENV.fetch("ANTHROPIC_API_KEY")
  end
end
