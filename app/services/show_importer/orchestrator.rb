# frozen_string_literal: true
class ShowImporter::Orchestrator
  attr_reader :show, :fm, :songs, :date, :show_found

  def initialize(date)
    @date = date

    puts 'Fetching show info...'
    @show_info = ShowImporter::ShowInfo.new(date)

    analyze_filenames

    @show = Show.unscoped.find_by(date: date)
    return if (@show_found = @show.present?)

    @show = Show.new(date: date, published: false)
    @venue = find_venue
    assign_venue
    populate_tracks
  end

  def analyze_filenames
    puts 'Analyzing filenames...'
    @fm = ShowImporter::FilenameMatcher.new("#{IMPORT_DIR}/#{date}")
  end

  def find_venue
    puts 'Finding venue...'
    Venue.left_outer_joins(:venue_renames)
         .where(
           '(venues.name = :name OR venue_renames.name = :name) AND city = :city',
           name: @show_info.venue_name,
           city: @show_info.venue_city
         ).first
  end

  def assign_venue
    return @show.venue = @venue if @venue.present?

    puts 'No venue matched! Enter Venue ID:'
    @venue = Venue.find($stdin.gets.chomp.to_i)
    @show.venue = @venue
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
    @tracks.insert pos, ShowImporter::TrackProxy.new(pos)
  end

  def delete(pos)
    @tracks.delete_if { |track| track.pos == pos }
    @tracks.each { |track| track.decr_pos if track.pos > pos }
  end

  def get_track(pos)
    @tracks.find { |s| s.pos == pos }
  end

  def save
    print 'Saving'

    @show.save
    @tracks.each do |track|
      next puts "\nInvalid track! (#{track.title})" unless track.valid?
      update_track(track)
      print '.'
    end
    @show.save_duration

    puts_success
  end

  private

  def update_track(track)
    track.update!(
      show: @show,
      audio_file: File.new("#{@fm.s_dir}/#{track.filename}")
    )
    track.apply_id3_tags
  end

  def puts_success
    puts "\n#{@show.date} show imported successfully"
  end

  def populate_tracks
    @tracks = []
    matches = @fm.matches.dup
    @show_info.songs.each do |pos, song_title|
      process_track(matches, pos, song_title)
    end
  end

  def process_track(matches, pos, song_title)
    if (fn_match = fn_match?(matches, song_title))
      @tracks << ShowImporter::TrackProxy.new(pos, song_title, fn_match[0], fn_match[1])
      return matches.delete(fn_match[0])
    end

    @tracks << ShowImporter::TrackProxy.new(pos, song_title)
  end

  def fn_match?(matches, song_title)
    matches.find { |_k, v| !v.nil? && v.title == song_title }
  end
end
