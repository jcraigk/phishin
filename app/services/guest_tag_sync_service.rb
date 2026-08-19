class GuestTagSyncService < ApplicationService
  BASE_URL = "https://api.phish.net/v5".freeze

  # Band members are named constantly in footnotes ("Fish on trombone") and are
  # never guests. A clause naming only these is skipped.
  BAND = /\A(trey|mike|page|fish(man)?|anastasio|gordon|mcconnell|the band|everyone)\b/i

  # Clauses that describe a guest. The footnote is already scoped to one song,
  # so the whole clause becomes the tag note, matching existing rows
  # ("Billy Strings on electric guitar").
  GUEST_PATTERNS = [
    /\bon\s+(?:lead\s+|rhythm\s+|acoustic\s+|electric\s+|alto\s+|tenor\s+|baritone\s+|soprano\s+)?
      (?:vocals?|guitar|bass|drums|percussion|keyboards?|piano|organ|
         saxophone|sax|trumpet|trombone|harmonica|fiddle|violin|banjo|
         mandolin|flute|clarinet|cello|horn|congas|washboard|accordian|accordion|vacuum)\b/xi,
    /\bguests?\b/i,
    /\bsat in\b/i,
    /\bjoin(?:s|ed)\b.*\bon\b/i
  ].freeze

  # Clauses that look guest-ish but are not.
  EXCLUSIONS = [
    /\bfor (?:the )?first known time\b/i,
    /\bphish debut\b/i,
    /\bunfinished\b/i,
    /\btease|quote\b/i
  ].freeze

  option :date, default: -> { nil }
  option :year, default: -> { nil }
  option :start_date, default: -> { nil }
  option :end_date, default: -> { nil }
  option :all, default: -> { false }
  option :dry_run, default: -> { true }
  option :verbose, default: -> { false }

  attr_reader :created, :existing, :unmatched

  def call
    validate_options!

    @created = []
    @existing = []
    @unmatched = []

    shows = fetch_shows
    puts "Scanning #{shows.count} show(s)#{dry_run ? ' (DRY RUN)' : ''}..."
    pbar = ProgressBar.create(total: shows.count, format: "%a %B %c/%C %p%% %E")

    shows.each do |show|
      process_show(show)
      pbar.increment
    end

    print_summary
  end

  private

  def validate_options!
    return if date || year || start_date || end_date || all
    raise ArgumentError, "Must specify DATE, YEAR, START_DATE, END_DATE, or ALL=true"
  end

  def fetch_shows
    scope =
      if date then Show.where(date:)
      elsif year then Show.where(date: Date.new(year.to_i).all_year)
      elsif start_date && end_date then Show.where(date: start_date..end_date)
      elsif start_date then Show.where("date >= ?", start_date)
      elsif end_date then Show.where("date <= ?", end_date)
      else Show.all
      end
    scope.includes(:tracks).order(date: :asc)
  end

  def guest_tag
    @guest_tag ||= Tag.find_by!(name: "Guest")
  end

  def process_show(show)
    fetch_setlist(show.date).each do |entry|
      guest_clauses(entry["footnote"]).each do |clause|
        apply(show, entry["song"].to_s, clause)
      end
    end
  end

  def guest_clauses(footnote)
    return [] if footnote.blank?

    normalize(footnote).split(/(?<=[.;])\s+/).filter_map do |clause|
      clause = clause.strip.sub(/[.;]\z/, "")
      next if clause.blank?
      next if EXCLUSIONS.any? { |re| clause.match?(re) }
      next if clause.match?(BAND)
      next unless GUEST_PATTERNS.any? { |re| clause.match?(re) }

      clause
    end
  end

  def apply(show, song, notes)
    track = find_track(show, song)
    return @unmatched << "#{show.date}: #{song} - #{notes}" if track.blank?

    if TrackTag.exists?(track:, tag: guest_tag, notes:)
      @existing << "#{show.date}: #{track.title}"
      return
    end

    @created << "#{show.date} | #{track.title} | #{notes}"
    return if dry_run

    TrackTag.create!(track:, tag: guest_tag, notes:)
  end

  def find_track(show, song)
    return nil if song.blank?

    show.tracks.find { |t| t.title.casecmp?(song) } ||
      show.tracks.find { |t| t.title.downcase.include?(song.downcase) } ||
      show.tracks.find { |t| song.downcase.include?(t.title.downcase) }
  end

  def fetch_setlist(show_date)
    response = Typhoeus.get("#{BASE_URL}/setlists/showdate/#{show_date}.json?apikey=#{pnet_api_key}")
    return [] unless response.success?

    Array(JSON.parse(response.body)["data"]).select { |entry| entry["artistid"].to_i == 1 }
  rescue JSON::ParserError
    []
  end

  def normalize(text)
    CGI.unescapeHTML(text.to_s.gsub(/<[^>]+>/, "")).gsub(/[“”]/, '"').gsub(/[‘’]/, "'").squish
  end

  def print_summary
    puts "\nGuest tags to create: #{created.size}"
    created.first(60).each { |c| puts "  #{c}" }
    puts "  ... and #{created.size - 60} more" if created.size > 60

    puts "\nAlready tagged: #{existing.size}"

    if unmatched.any?
      puts "\nUnmatched songs (#{unmatched.size}):"
      unmatched.first(20).each { |u| puts "  #{u}" }
    end

    puts "\nDry run. Re-run with DRY_RUN=false to create these tags." if dry_run && created.any?
  end

  def pnet_api_key
    @pnet_api_key ||= ENV.fetch("PNET_API_KEY")
  end
end
