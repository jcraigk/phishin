class ShowImporter::Orchestrator
  attr_reader :fm, :date, :show_found, :path

  def initialize(date, exclude_from_stats: false)
    Track.attr_accessor(:filename)

    @date = date
    @path = "#{App.content_import_path}/#{date}"
    @exclude_from_stats = exclude_from_stats

    analyze_filenames

    return if (@show_found = Show.find_by(date:).present?)

    populate_tracks
    assign_venue
    assign_tour
    import_notes
  end

  # Reuses the Matcher's fetch when one ran, so Phish.net is hit once per import.
  def show_info
    return @matcher_result.show_info if @matcher_result
    @show_info ||= ShowImporter::ShowInfo.new(date)
  end

  def show
    @show ||= Show.new(date:)
  end

  def pp_list
    @tracks.sort_by(&:position).each { |t| puts track_display(t) }
  end

  def save
    print "🍩 Processing..."
    pbar = ProgressBar.create(total: @tracks.size, format: "%a %B %c/%C %p%% %E")

    show.performance_gap_value = 0 if @exclude_from_stats
    show.save!
    save_tracks(pbar)
    show.reload.save_duration

    pbar.finish

    InteractiveCoverArtService.call(Show.where(id: show.id))
    DebutTagService.call(show)
    LoreSyncService.call(date: show.date.to_s)
    sync_teases
    save_song_performance_data(show)
    create_announcement
    clear_rails_cache
  end

  def get_track(position)
    @tracks.find { |t| t.position == position }
  end

  def track_display(track)
    (valid?(track) ? "  " : "* ") +
      format(
        "%2d. [%1s] %-30.30s     %-30.30s     ",
        track.position,
        track.set,
        track.title,
        track.filename
      ) + track.songs.map { |song| format("(%-3d) %-20.20s", song.id, song.title) }.join("   ")
  end

  def merge_tracks(subsumed_track, subsuming_track)
    subsuming_track.title += " > #{subsumed_track.title}"
    subsuming_track.songs << subsumed_track.songs.reject { |s| subsuming_track.songs.include?(s) }
    subsuming_track.filename ||= subsumed_track.filename
    @tracks.delete(subsumed_track)
  end

  def combine_up(position)
    subsumed_track = get_track(position)
    subsuming_track = get_track(position - 1)
    return if subsumed_track.nil? || subsuming_track.nil?
    merge_tracks(subsumed_track, subsuming_track)
    @tracks.each { |track| track.position -= 1 if track.position > position }
  end

  def insert_before(position)
    set = get_track(position).set
    @tracks.each { |track| track.position += 1 if track.position >= position }
    @tracks.insert position, Track.new(position:, set:)
  end

  def delete(position)
    @tracks.delete_if { |track| track.position == position }
    @tracks.each { |track| track.position -= 1 if track.position > position }
  end

  private

  # Teases live in the Tagin' spreadsheet, so append any the setlist notes
  # describe and then pull the sheet's Tease rows into the database. A failure
  # here must not abort an otherwise successful import.
  def sync_teases
    puts "Scanning setlist notes for teases..."
    service = TeaseSyncService.new(date: show.date.to_s, apply: true)
    service.call
    return if service.proposed_rows.none?

    data = GoogleSpreadsheetFetcher.call(ENV.fetch("TAGIN_GSHEET_ID"), "Tease!A1:G5000", headers: true)
    TrackTagSyncService.call("Tease", data.select { |row| row["URL"].to_s.include?("/#{show.date}/") })
  rescue StandardError => e
    puts "⚠️  Tease sync failed (#{e.class}: #{e.message}); continuing import."
  end

  def save_song_performance_data(show)
    puts "Calculating song performance data and applying bustout tag..."
    GapService.call(show, update_previous: true)
    BustoutTagService.call(show)
  end

  def create_announcement
    show_name = "#{show.date} at #{show.venue_name}"
    Announcement.create! \
      title: "New content: #{show_name}",
      description: "A new show has been added: #{show_name}",
      url: "#{App.base_url}/#{show.date}"
  end

  def analyze_filenames
    @fm = ShowImporter::FilenameMatcher.new(path)
  end

  def venue
    @venue ||= @matcher_result&.venue
  end

  def tour
    @tour ||= @matcher_result&.tour
  end

  def assign_venue
    return show.venue = venue if venue.present?

    puts "No venue matched! Enter Venue ID:"
    @venue = Venue.find($stdin.gets.chomp.strip.to_i)
    show.venue = venue
  end

  def assign_tour
    return show.tour = tour if tour.present?

    puts "No tour matched! Enter Tour ID:"
    @tour = Tour.find($stdin.gets.chomp.strip.to_i)
    show.tour = tour
  end

  def import_notes
    return unless File.exist?(notes_file)
    show.taper_notes = File.read(notes_file)
  end

  def notes_file
    "#{path}/notes.txt"
  end

  def save_tracks(pbar)
    @tracks.each do |track|
      next puts "\n❌ Invalid track! (#{track.title})" unless valid?(track)
      save_track(track)
      pbar.increment
    end
  end

  def valid?(track)
    track.filename.present? &&
      track.title.present? &&
      track.position.present? &&
      track.songs.to_a.present? &&
      track.set.present?
  end

  def save_track(track)
    track.show = show
    track.exclude_from_stats = true if @exclude_from_stats
    track.save!
    track.mp3_audio.attach \
      io: File.open("#{@fm.dir}/#{track.filename}"),
      filename: track.friendly_filename,
      content_type: "audio/mpeg"
    track.process_mp3_audio
  end

  def populate_tracks
    @matcher_result = ShowImporter::Matcher.call(date:, filenames: fm.matches.keys)
    @tracks = @matcher_result.tracks.map { |attrs| build_track(attrs) }
  end

  def build_track(attrs)
    track = Track.new(
      position: attrs[:position],
      title: attrs[:title],
      set: attrs[:set],
      filename: attrs[:filename]
    )
    track.songs << Song.find(attrs[:song_id]) if attrs[:song_id]
    track
  end

  def clear_rails_cache
    Rails.cache.clear
  end
end
