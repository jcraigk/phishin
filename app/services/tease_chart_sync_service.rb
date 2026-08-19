require "nokogiri"

class TeaseChartSyncService < ApplicationService
  CHART_URL = "https://phish.net/tease-chart".freeze
  SHEET_RANGE = "Tease!A1:G5000".freeze
  APPEND_RANGE = "Tease!A:F".freeze
  UNMATCHED_RANGE = "UNMATCHED TEASES!A:E".freeze
  DEV_NOTE = "Imported from Phish.net Tease Chart".freeze

  option :year, default: -> { nil }
  option :start_date, default: -> { nil }
  option :end_date, default: -> { nil }
  option :all, default: -> { false }
  option :apply, default: -> { false }
  option :verbose, default: -> { false }

  attr_reader :proposed_rows, :unmatched, :skipped_existing

  def call
    validate_options!

    @proposed_rows = []
    @unmatched = []
    @skipped_existing = 0
    @existing = load_existing_rows

    occurrences = fetch_chart_occurrences.select { |occ| in_scope?(occ[:date]) }
    puts "Chart occurrences in scope: #{occurrences.size}"

    occurrences.each { |occ| evaluate(occ) }

    print_summary
    return unless apply

    append_rows if proposed_rows.any?
    append_unmatched if unmatched.any?
  end

  private

  def validate_options!
    return if year || start_date || end_date || all
    raise ArgumentError, "Must specify YEAR, START_DATE, END_DATE, or ALL=true"
  end

  def in_scope?(date)
    return true if all
    return date.start_with?(year.to_s) if year
    return false if start_date && date < start_date.to_s
    return false if end_date && date > end_date.to_s
    true
  end

  # The chart is one row per teased song, with every occurrence listed in the
  # Dates cell as "YYYY-MM-DD <abbreviated host song>".
  def fetch_chart_occurrences
    response = Typhoeus.get(CHART_URL, followlocation: true, timeout: 60, headers: { "User-Agent" => "phish.in tease sync" })
    raise "Tease chart fetch failed (HTTP #{response.code})" unless response.success?

    Nokogiri::HTML(response.body).css("table tr").flat_map do |row|
      cells = row.css("td").map { |cell| cell.text.strip.squish }
      next [] if cells.size < 4

      parse_occurrences(cells)
    end
  end

  def parse_occurrences(cells)
    tease, artist = cells[0], cells[1]
    cells[3].split(/,\s*/).filter_map do |occurrence|
      next unless occurrence =~ /\A(\d{4}-\d{2}-\d{2})\s*(.*)\z/
      { date: Regexp.last_match(1), song: Regexp.last_match(2).to_s.strip, tease:, artist: }
    end
  end

  def evaluate(occ)
    show = shows_by_date[occ[:date]]
    return record_unmatched(occ, "no show on phish.in") if show.blank?

    track = find_track(show, occ[:song])
    return record_unmatched(occ, occ[:song].blank? ? "chart lists no song" : "no track matched") if track.blank?

    note = format_note(occ[:tease], occ[:artist])
    if already_covered?(track, note)
      @skipped_existing += 1
      return log("  skip: #{occ[:date]} #{track.title} - #{note}")
    end

    row = [ sheet_url(track), "", "", note, "", DEV_NOTE ]
    # The chart can list the same tease twice for one show (e.g. two teases in one
    # jam); they collapse to one track URL, so keep a single row.
    if @proposed_rows.any? { |r| r[0] == row[0] && normalize_note(r[3]) == normalize_note(note) }
      @skipped_existing += 1
      return log("  skip (duplicate in batch): #{occ[:date]} #{track.title} - #{note}")
    end

    log("  propose: #{occ[:date]} #{track.title} - #{note}")
    @proposed_rows << row
  end

  def record_unmatched(occ, reason)
    @unmatched << { date: occ[:date], song: occ[:song], note: format_note(occ[:tease], occ[:artist]), reason: }
  end

  def format_note(tease, artist)
    tease = clean(tease)
    artist = clean(artist)
    # The chart disambiguates same-named songs as "Fire (Ohio Players)"; drop the
    # parenthetical when it just repeats the artist column.
    tease = tease.sub(/\s*\((.+?)\)\s*\z/) { Regexp.last_match(1).casecmp?(artist) ? "" : Regexp.last_match(0) }
    # A few chart rows carry a stray number in the Artist column; treat as unknown.
    artist = "" if artist.match?(/\A[\d\s.]+\z/)
    return tease if artist.blank? || artist.casecmp?("Phish")
    "#{tease} by #{artist}"
  end

  def clean(str)
    CGI.unescapeHTML(str.to_s).gsub(/[“”]/, '"').gsub(/[‘’]/, "'").squish
  end

  def shows_by_date
    @shows_by_date ||= Show.includes(:tracks).index_by { |show| show.date.to_s }
  end

  # Chart labels are abbreviations ("YEM", "SOAMelt"). Phish.net's song catalog
  # carries the same abbreviations, so resolve through it before matching titles.
  def song_titles
    @song_titles ||= begin
      response = Typhoeus.get("https://api.phish.net/v5/songs.json?apikey=#{pnet_api_key}")
      raise "Phish.net songs API error: #{response.body}" unless response.success?

      JSON.parse(response.body)["data"].each_with_object({}) do |song, hash|
        title = song["song"].to_s
        hash[normalize(title)] ||= title
        abbr = CGI.unescapeHTML(song["abbr"].to_s)
        hash[normalize(abbr)] ||= title if abbr.present?
      end
    end
  end

  def find_track(show, label)
    return nil if label.blank?

    candidates = [ song_titles[normalize(label)], label ].compact
    candidates.each do |candidate|
      key = normalize(candidate)
      match = show.tracks.find { |t| normalize(t.title) == key } ||
              show.tracks.find { |t| normalize(t.title).include?(key) } ||
              show.tracks.find { |t| key.include?(normalize(t.title)) }
      return match if match
    end
    nil
  end

  def load_existing_rows
    GoogleSpreadsheetFetcher.call(sheet_id, SHEET_RANGE, headers: true)
      .each_with_object(Hash.new { |h, k| h[k] = [] }) do |row, hash|
        key = track_key(row["URL"])
        next if key.blank?
        hash[key] << normalize_note(row["Notes"].to_s)
      end
  end

  def already_covered?(track, note)
    existing = @existing[track_key(sheet_url(track))]
    return false if existing.blank?

    candidate = normalize_note(note)
    title = candidate.split(" by ").first.to_s
    existing.any? do |existing_note|
      existing_title = existing_note.split(" by ").first.to_s
      existing_note == candidate || existing_title == title ||
        (title.present? && (existing_title.include?(title) || title.include?(existing_title)))
    end
  end

  def track_key(url)
    return nil if url.blank?
    segments = URI.parse(url.strip).path.split("/")
    return nil if segments.size < 2
    segments.last(2).join("/")
  rescue URI::InvalidURIError
    nil
  end

  def sheet_url(track)
    "#{Rails.configuration.production_base_url}/#{track.show.date}/#{track.slug}"
  end

  def normalize(str)
    CGI.unescapeHTML(str.to_s).downcase.gsub(/[^a-z0-9 ]/, "").squish
  end

  def normalize_note(str)
    CGI.unescapeHTML(str.to_s).downcase.gsub(/[[:punct:]]/, "").squish
  end

  def append_rows
    proposed_rows.each_slice(500) do |batch|
      GoogleSpreadsheetAppender.call(sheet_id, APPEND_RANGE, batch)
    end
    puts "Appended #{proposed_rows.size} row(s) to the Tease tab."
    puts "Run `bin/rails tagin:sync` to pull them into the database."
  end

  def append_unmatched
    rows = unmatched.map { |e| [ e[:date], e[:song], e[:note], e[:reason], DEV_NOTE ] }
    rows.each_slice(500) { |batch| GoogleSpreadsheetAppender.call(sheet_id, UNMATCHED_RANGE, batch) }
    puts "Appended #{rows.size} row(s) to the UNMATCHED TEASES tab."
  rescue Google::Apis::ClientError => e
    raise unless e.message.to_s.match?(/unable to parse range|not found/i)
    puts "\nCould not write unmatched rows: no 'UNMATCHED TEASES' tab found."
  end

  def print_summary
    puts "\nProposed rows: #{proposed_rows.size}"
    proposed_rows.first(40).each { |row| puts "  #{row[0]} - #{row[3]}" }
    puts "  ... and #{proposed_rows.size - 40} more" if proposed_rows.size > 40

    puts "\nAlready in sheet (skipped): #{skipped_existing}"

    if unmatched.any?
      puts "\nUnmatched (#{unmatched.size}):"
      unmatched.group_by { |e| e[:reason] }.each do |reason, entries|
        puts "  #{reason}: #{entries.size}"
        entries.first(5).each { |e| puts "      #{e[:date]} #{e[:song]} - #{e[:note]}" }
      end
    end

    puts "\nDry run. Re-run with APPLY=true to append these rows." if !apply && proposed_rows.any?
  end

  def log(message)
    puts message if verbose
  end

  def sheet_id
    @sheet_id ||= ENV.fetch("TAGIN_GSHEET_ID")
  end

  def pnet_api_key
    @pnet_api_key ||= ENV.fetch("PNET_API_KEY")
  end
end
