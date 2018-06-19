# frozen_string_literal: true
class ShowImporter::TrackReplacer
  attr_reader :date, :dir

  def initialize(date)
    @date = date

    puts 'Show found...matching files to tracks'
    tracks = match_files_to_tracks
    binding.pry
  end

  def match_files_to_tracks
    filenames.each_with_object({}) do |filename, tracks|
      binding.pry
      tracks[filename] =
        Track.where(show_id: show.id)
             .kinda_matching(scrub_filename(filename))
             .first
    end
  end

  private

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