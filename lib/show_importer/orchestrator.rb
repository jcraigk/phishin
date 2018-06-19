# frozen_string_literal: true
class ShowImporter::Orchestrator
  attr_reader :show, :fm, :songs, :date

  def initialize(date)
    @date = date

    puts 'Fetching show info...'
    @show_info = ShowImporter::ShowInfo.new(date)

    analyze_filenames

    @show = Show.where(date: date).first
    return if @show.present?

    binding.pry

    @show = Show.new(date: date)
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
    venue = Venue.where(name: @show_info.venue_name, city: @show_info.venue_city).first
    return veneu if venue.present?
    Venue.where(
      'past_names LIKE ? AND city = ?',
      "%#{@show_info.venue_name}%",
      @show_info.venue_city
    ).first
  end

  def assign_venue
    unless @venue.present?
      puts 'No venue matched! Enter Venue ID:'
      @venue = Venue.find(STDIN.gets.chomp.to_i)
    end
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
    @show.save
    duration = 0
    @tracks.each do |t|
      next unless t.valid?
      t.show = @show
      t.audio_file = File.new("#{@fm.s_dir}/#{t.filename}")
      t.save!
      t.save_default_id3_tags
      begin
        duration += t.duration
      rescue => e
        puts e
        p "Duration error on #{t}"
      end
    end
    @show.update_attributes(duration: duration)
  end

  private

  def populate_tracks
    @tracks = []
    matches = @fm.matches.dup
    @show_info.songs.each do |pos, song_title|
      fn_match = matches.find { |_k, v| !v.nil? && v.title == song_title }
      if fn_match
        @tracks << ShowImporter::TrackProxy.new(pos, song_title, fn_match[0], fn_match[1])
        matches.delete(fn_match[0])
      else
        @tracks << ShowImporter::TrackProxy.new(pos, song_title)
      end
    end
  end
end
