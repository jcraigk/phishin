# frozen_string_literal: true
require 'highline'

class ShowImporter::TrackReplacer
  attr_reader :date, :dir, :tracks

  def initialize(date)
    @date = date

    puts 'Show already imported!'
    @tracks = match_files_to_tracks
    ensure_tracks_present
    cli = HighLine.new
    answer = cli.ask "Proceed with track replacement? [Y/n]"
    replace_audio_on_tracks if answer == 'Y'
  end

  def match_files_to_tracks
    filenames.each_with_object({}) do |filename, tracks|
      tracks[filename] =
        Track.where(show_id: show.id)
             .kinda_matching(scrub_filename(filename))
             .first
    end
  end

  private

  def replace_audio_on_tracks
    tracks.sort.each do |filename, track|
      full_path = "#{IMPORT_DIR}/#{date}/#{filename}"
      track.audio_file = File.open(full_path, 'rb')
      track.save
      puts "#{track.position}. #{track.title} replaced with `#{filename}`"
    end
  end

  def ensure_tracks_present
    return unless any_tracks_nil?
    puts tracks.inspect
    raise "Could not match all files to tracks!"
  end

  def any_tracks_nil?
    tracks.values.include?(nil)
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
        e == '.' || e == '..' || e =~ /.txt\z/
      end
  end
end