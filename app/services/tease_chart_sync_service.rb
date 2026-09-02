require "nokogiri"

class TeaseChartSyncService < ApplicationService
  CHART_URL = "https://phish.net/tease-chart".freeze
  # The chart page has a few names whose accented bytes are already lost upstream
  # (they arrive as U+FFFD), so they cannot be repaired by re-decoding.
  LOST_CHARACTER_FIXES = {
    "Beyonc\uFFFD" => "Beyonc\u00E9",
    "Mel Torm\uFFFD and Bob Wells" => "Mel Torm\u00E9 and Bob Wells",
    "Vin\uFFFDcius de Moraes and Ant\uFFFDnio Carlos Jobim" =>
      "Vin\u00EDcius de Moraes and Ant\u00F4nio Carlos Jobim"
  }.freeze

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

    create_track_tags if proposed_rows.any?
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

    # Typhoeus hands back ASCII-8BIT despite the charset=utf-8 header; without this
    # Nokogiri assumes Latin-1 and double-encodes every accented character.
    html = response.body.dup.force_encoding(Encoding::UTF_8)
    Nokogiri::HTML(html).css("table tr").flat_map do |row|
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

    tracks = find_tracks(show, occ[:song])
    return record_unmatched(occ, occ[:song].blank? ? "chart lists no song" : "no track matched") if tracks.empty?

    track = tracks.first
    note = format_note(occ[:tease], occ[:artist])
    if tracks.any? { |t| already_covered?(t, note) }
      @skipped_existing += 1
      return log("  skip: #{occ[:date]} #{track.title} - #{note}")
    end

    # The chart can list the same tease twice for one show (e.g. two teases in one
    # jam); they collapse to one track, so keep a single proposal.
    if @proposed_rows.any? { |p| p[:track].id == track.id && normalize_note(p[:note]) == normalize_note(note) }
      @skipped_existing += 1
      return log("  skip (duplicate in batch): #{occ[:date]} #{track.title} - #{note}")
    end

    log("  propose: #{occ[:date]} #{track.title} - #{note}")
    @proposed_rows << { track:, note: }
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
    str = repair_encoding(CGI.unescapeHTML(str.to_s))
    LOST_CHARACTER_FIXES.fetch(str, str).gsub(/[“”]/, '"').gsub(/[‘’]/, "'").squish
  end

  # Undo one round of UTF-8 bytes having been decoded as Latin-1.
  def repair_encoding(str)
    return str if str.ascii_only?

    candidate = str.encode(Encoding::ISO_8859_1).force_encoding(Encoding::UTF_8)
    candidate.valid_encoding? ? candidate : str
  rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    str
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

  # Chart labels are abbreviations ("YEM", "SOAMelt"); try the catalog title first.
  def find_tracks(show, label)
    return [] if label.blank?
    TeaseTrackMatcher.call(show, [ song_titles[normalize(label)], label ].compact)
  end

  def load_existing_rows
    TrackTag.joins(:tag).where(tags: { name: "Tease" })
            .includes(track: :show)
            .each_with_object(Hash.new { |h, k| h[k] = [] }) do |track_tag, hash|
      hash[track_key_for(track_tag.track)] << normalize_note(track_tag.notes.to_s)
    end
  end

  def already_covered?(track, note)
    existing = @existing[track_key_for(track)]
    return false if existing.blank?

    candidate = normalize_note(note)
    title = candidate.split(" by ").first.to_s
    existing.any? do |existing_note|
      existing_title = existing_note.split(" by ").first.to_s
      existing_note == candidate || existing_title == title ||
        (title.present? && (existing_title.include?(title) || title.include?(existing_title)))
    end
  end

  def track_key_for(track)
    "#{track.show.date}/#{TrackSlugGenerator.call(track)}"
  end

  def normalize(str)
    CGI.unescapeHTML(str.to_s).downcase.gsub(/[^a-z0-9 ]/, "").squish
  end

  def normalize_note(str)
    CGI.unescapeHTML(str.to_s).downcase.gsub(/[[:punct:]]/, "").squish
  end

  def create_track_tags
    tag = Tag.find_by!(name: "Tease")
    proposed_rows.each do |proposal|
      TrackTag.create!(tag:, track: proposal[:track], notes: proposal[:note])
    end
    puts "Created #{proposed_rows.size} Tease tag(s)."
  end

  def print_summary
    puts "\nProposed tags: #{proposed_rows.size}"
    proposed_rows.first(40).each { |p| puts "  #{track_key_for(p[:track])} - #{p[:note]}" }
    puts "  ... and #{proposed_rows.size - 40} more" if proposed_rows.size > 40

    puts "\nAlready tagged (skipped): #{skipped_existing}"

    if unmatched.any?
      puts "\nUnmatched (#{unmatched.size}):"
      unmatched.group_by { |e| e[:reason] }.each do |reason, entries|
        puts "  #{reason}: #{entries.size}"
        entries.first(5).each { |e| puts "      #{e[:date]} #{e[:song]} - #{e[:note]}" }
      end
    end

    puts "\nDry run. Re-run with APPLY=true to create these tags." if !apply && proposed_rows.any?
  end

  def log(message)
    puts message if verbose
  end

  def pnet_api_key
    @pnet_api_key ||= ENV.fetch("PNET_API_KEY")
  end
end
