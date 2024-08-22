class ShowImporter::Orchestrator
  attr_reader :fm, :date, :show_found, :path, :show_info

  SET_MAP = {
    "3" => %w[III],
    "E" => %w[e I-e II-e],
    "2" => %w[II],
    "1" => %w[I],
    "S" => %w[(Check)]
  }.freeze

  def initialize(date) # rubocop:disable Metrics/MethodLength
    Track.attr_accessor(:filename)

    @date = date
    @path = "#{App.content_import_path}/#{date}"
    @show_info = ShowImporter::ShowInfo.new(date)
    @used_files = []

    analyze_filenames

    return if (@show_found = Show.find_by(date:).present?)

    assign_venue
    assign_tour
    import_notes
    populate_tracks
  end

  def show
    @show ||= Show.new(date:, published: false)
  end

  def pp_list
    @tracks.sort_by(&:position).each { |t| puts track_display(t) }
  end

  def save
    print "🍩 Processing..."
    pbar = ProgressBar.create(total: @tracks.size, format: "%a %B %c/%C %p%% %E")

    show.save!

    save_tracks(pbar)

    show.reload.save_duration
    show.update!(published: true)

    create_announcement

    pbar.finish
    success
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
    @venue ||=
      Venue.left_outer_joins(:venue_renames)
           .where(
             "(venues.name = :name OR venue_renames.name = :name) AND city = :city",
             name: show_info.venue_name,
             city: show_info.venue_city
           ).first
  end

  def tour
    @tour ||=
      Tour.where("starts_on <= :date AND ends_on >= :date", date:)
          .first
  end

  def assign_venue
    return show.venue = venue if venue.present?

    puts "No venue matched! Enter Venue ID:"
    @venue = Venue.find($stdin.gets.chomp.to_i)
    show.venue = venue
  end

  def assign_tour
    return show.tour = tour if tour.present?

    puts "No tour matched! Enter Tour ID:"
    @tour = Tour.find($stdin.gets.chomp.to_i)
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
    track.save!(validate: false) # Generate ID for audio_file storage
    track.update!(audio_file: File.open("#{@fm.dir}/#{track.filename}"))
  end

  def success
    puts "✅ Import complete: #{show.url}\n\n"
  end

  def populate_tracks
    @tracks = []
    @matches = @fm.matches.dup

    show_info.songs.each do |position, title|
      process_track(position, title)
    end
  end

  # rubocop:disable Metrics/MethodLength
  def process_track(position, title)
    if (match = fn_match?(title))
      filename = match.first
      song = match.second
      track = Track.new(
        set: musical_set_from_fn(filename),
        position:,
        title: song.title,
        filename:
      )
      track.songs << song if song.present?
    else
      track = Track.new(position:, title:)
    end

    @tracks << track
  end
  # rubocop:enable Metrics/MethodLength

  def fn_match?(title)
    unused_matches.find { |_k, v| !v.nil? && v.title == title }.tap do |k, _v|
      @used_files << k
    end
  end

  def unused_matches
    @matches.except(*@used_files)
  end

  def musical_set_from_fn(filename)
    SET_MAP.each do |set, values|
      values.each do |value|
        return set if filename&.start_with?(value)
      end
    end

    "1"
  end
end
