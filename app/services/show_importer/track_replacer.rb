# frozen_string_literal: true
require 'highline'

class ShowImporter::TrackReplacer
  attr_reader :date, :track_hash

  def initialize(date)
    @date = date
    @show = Show.find_by(date: date)

    puts 'Show already imported!'
    @track_hash = match_files_to_tracks
    ensure_tracks_present
    ensure_all_tracks_matched
    cli = HighLine.new
    answer = cli.ask 'Proceed with track replacement? [Y/n]'
    replace_audio_on_tracks if answer == 'Y'
  end

  def match_files_to_tracks
    filenames.each_with_object({}) do |filename, track_hash|
      tracks_kinda_matching(filename).each do |track|
        next if track_hash.value?(track) # Handle multiple instances of song
        break track_hash[filename] = track
      end
    end
  end

  private

  def tracks_kinda_matching(filename)
    Track.where(show_id: show.id)
         .kinda_matching(scrub_filename(filename))
         .order(position: :asc)
  end

  def replace_audio_on_tracks # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    track_hash.sort_by { |_k, v| v.position }
              .each do |filename, track|
      full_path = "#{IMPORT_DIR}/#{date}/#{filename}"
      track.audio_file = File.open(full_path, 'rb')
      track.save
      track.save_duration
      track.apply_id3_tags
      track.generate_waveform_image
      puts "#{track.position}. #{track.title} (#{track.id}) replaced with `#{filename}`"
    end
    show.save_duration
  end

  def ensure_tracks_present
    return unless nil_tracks.any?
    raise "Not all files matched: #{nil_tracks.keys}"
  end

  def nil_tracks
    track_hash.select { |_k, v| v.nil? }
  end

  def ensure_all_tracks_matched
    return if unmatched_tracks.empty?
    raise "Not all tracks matched: #{unmatched_tracks}"
  end

  def unmatched_tracks
    @unmatched_tracks ||= show.track_ids - track_hash.values.map(&:id)
  end

  def scrub_filename(filename)
    return '555' if /555/i.match?(filename)
    return "Mike's Song" if /mike/i.match?(filename)
    return 'Free Bird' if /Freebird.mp3/.match?(filename)
    filename
      .gsub('.mp3', '')
      .gsub(/\AII?/, '')
      .tr('_', ' ')
      .gsub(/\d/, '')
      .strip
  end

  def show
    @show ||= Show.find_by(date: date)
  end

  def dir
    @dir ||= "#{::IMPORT_DIR}/#{date}"
  end

  def filenames
    @filenames ||=
      Dir.entries(dir).reject do |e|
        e == '.' || e == '..' || e =~ /.txt\z/ || e == '.DS_Store'
      end
  end
end
