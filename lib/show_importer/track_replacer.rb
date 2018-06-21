# frozen_string_literal: true
require 'highline'

class ShowImporter::TrackReplacer
  attr_reader :date, :dir, :track_hash, :show

  def initialize(date)
    @date = date
    @show = Show.where(date: date).first

    puts 'Show already imported!'
    @track_hash = match_files_to_tracks
    ensure_tracks_present
    ensure_all_tracks_matched
    cli = HighLine.new
    answer = cli.ask "Proceed with track replacement? [Y/n]"
    replace_audio_on_tracks if answer == 'Y'
  end

  def match_files_to_tracks
    filenames.each_with_object({}) do |filename, track_hash|
      track_hash[filename] =
        Track.where(show_id: show.id)
             .kinda_matching(scrub_filename(filename))
             .first
    end
  end

  private

  def replace_audio_on_tracks
    track_hash.sort.each do |filename, track|
      full_path = "#{IMPORT_DIR}/#{date}/#{filename}"
      track.audio_file = File.open(full_path, 'rb')
      track.save
      puts "#{track.position}. #{track.title} (#{track.id}) replaced with `#{filename}`"
    end
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
    if /mike/i.match?(filename)
      "Mike's Song"
    elsif /Freebird.mp3/.match?(filename)
      'Free Bird'
    else
      filename
        .gsub('.mp3', '')
        .gsub(/\AII?/, '')
        .tr('_', ' ')
        .gsub(/\d/, '')
        .strip
    end
  end

  def show
    @show ||= Show.where(date: date).first
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