# frozen_string_literal: true
class ShowImporter::Orchestrator
  attr_reader :fm, :date, :show_found, :path, :show_info

  def initialize(date)
    @date = date
    @path = "#{IMPORT_DIR}/#{date}"
    @show_info = ShowImporter::ShowInfo.new(date)

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

  def analyze_filenames
    @fm = ShowImporter::FilenameMatcher.new(path)
  end

  def venue
    @venue ||=
      Venue.left_outer_joins(:venue_renames)
           .where(
             '(venues.name = :name OR venue_renames.name = :name) AND city = :city',
             name: show_info.venue_name,
             city: show_info.venue_city
           ).first
  end

  def tour
    @tour ||= Tour.where('starts_on <= :date AND ends_on >= :date', date:).first
  end

  def assign_venue
    return show.venue = venue if venue.present?

    puts 'No venue matched! Enter Venue ID:'
    @venue = Venue.find($stdin.gets.chomp.to_i)
    show.venue = venue
  end

  def assign_tour
    return show.tour = tour if tour.present?

    puts 'No tour matched! Enter Tour ID:'
    @tour = Tour.find($stdin.gets.chomp.to_i)
    show.tour = tour
  end

  def pp_list
    @tracks.sort_by(&:pos).each do |track|
      puts track
    end
  end

  def combine_up(pos)
    assimilating = get_track(pos)
    receiving = get_track(pos - 1)

    return if assimilating.nil? || receiving.nil?

    receiving.merge_track(assimilating)
    @tracks.delete assimilating

    @tracks.each { |track| track.decr_pos if track.pos > pos }
  end

  def insert_before(pos)
    @tracks.each { |track| track.incr_pos if track.pos >= pos }
    @tracks.insert pos, ShowImporter::TrackProxy.new(pos:)
  end

  def delete(pos)
    @tracks.delete_if { |track| track.pos == pos }
    @tracks.each { |track| track.decr_pos if track.pos > pos }
  end

  def get_track(pos)
    @tracks.find { |s| s.pos == pos }
  end

  def import_notes
    return unless File.exist?(notes_file)
    show.taper_notes = File.read(notes_file)
  end

  def save
    print '🍩 Processing...'
    pbar = ProgressBar.create(total: @tracks.size, format: '%a %B %c/%C %p%% %E')

    show.save
    save_tracks(pbar)
    show.save_duration
    show.update!(published: true)

    pbar.finish
    success
  end

  private

  def notes_file
    "#{path}/notes.txt"
  end

  def save_tracks(pbar)
    @tracks.each do |track|
      next puts "\n❌ Invalid track! (#{track.title})" unless track.valid?
      create_real_track(track)
      pbar.increment
    end
  end

  def create_real_track(track)
    track.show = show
    track.save!(validate: false) # Generate ID for audio_file storage
    track.update!(audio_file: File.open("#{@fm.dir}/#{track.filename}"))
    track.process_audio_file
  end

  def success
    puts "✅ #{show.date} imported"
  end

  def populate_tracks
    @tracks = []
    matches = @fm.matches.dup
    show_info.songs.each do |pos, title|
      process_track(matches, pos, title)
    end
  end

  def process_track(matches, pos, title)
    if (fn_match = fn_match?(matches, title))
      @tracks << ShowImporter::TrackProxy.new(
        pos:,
        title:,
        filename: fn_match.first,
        song: fn_match.second
      )
      return matches.delete(fn_match.first)
    end

    @tracks << ShowImporter::TrackProxy.new(pos:, title:)
  end

  def fn_match?(matches, title)
    matches.find { |_k, v| !v.nil? && v.title == title }
  end
end
