require_relative '../../config/environment'
require_relative '../filename_matcher'
require_relative 'show_info'
require_relative 'track_proxy'
require_relative 'cli'

module ShowImporter
  class ShowImporter
    attr_reader :show, :fm, :songs

    def initialize(date)
      puts 'Fetching show info...'
      @show_info = ShowInfo.new(date)

      puts 'Analyzing filenames...'
      @fm = FilenameMatcher.new(date)

      @show = Show.where(date: date).first
      if @show.present?
        puts "Show for #{date} already imported!"
        exit
      end
      @show = Show.new(date: date)

      puts 'Finding venue...'
      @venue = Venue.where(name: @show_info.venue_name, city: @show_info.venue_city).first
      @venue ||= Venue.where(
        'past_names LIKE ? AND city = ?',
        "%#{@show_info.venue_name}%",
        @show_info.venue_city
      ).first
      unless @venue.present?
        puts 'No venue matched! Enter Venue ID:'
        @venue = Venue.find(STDIN.gets.chomp.to_i)
      end
      @show.venue = @venue

      @tracks = []
      populate_tracks
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
      @tracks.insert pos, TrackProxy.new(pos)
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
        rescue
          p 'Duration error on #{t}'
        end
      end
      @show.update_attributes(duration: duration)
    end

    private

    def populate_tracks
      matches = @fm.matches.dup
      @show_info.songs.each do |pos, song_title|
        fn_match = matches.find { |_k, v| !v.nil? && v.title == song_title }
        if fn_match
          @tracks << TrackProxy.new(pos, song_title, fn_match[0], fn_match[1])
          matches.delete(fn_match[0])
        else
          @tracks << TrackProxy.new(pos, song_title)
        end
      end
    end
  end
end
