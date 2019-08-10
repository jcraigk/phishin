# frozen_string_literal: true
class ShowImporter::FilenameMatcher
  attr_reader :matches, :s_dir

  def initialize(dir)
    @s_dir = dir
    unless File.directory?(@s_dir)
      puts "TRIED: #{@s_dir}"
      raise 'Must provide a valid directory path'
    end

    find_matches
  end

  def find_matches
    @matches = {}
    filenames.each do |filename|
      s_filename = scrub_filename(filename)
      found = find_match(s_filename)
      @matches[filename] = found
    end

    @matches = Hash[@matches.sort]
  end

  def filenames
    @filenames ||= begin
      Dir.entries(@s_dir).reject do |e|
        e == '.' || e == '..' || e =~ /.txt\z/
      end
    end
  end

  def submit_correction(filename, search_term)
    return false unless @matches.key?(filename)

    match = find_match(search_term, exact: true)
    if match
      @matches[filename] = match
      true
    else
      false
    end
  end

  def pp_matches
    @matches.each do |filename, match|
      puts "#{filename} -- #{match.title}"
    end
  end

  def all_matched?
    @matches.values.select(&:nil?).empty?
  end

  def find_match(term, opts = {})
    return Song.where('lower(title) = ?', term.downcase).first if opts[:exact]
    Song.kinda_matching(term).first
  end

  private

  def scrub_dir_path(path)
    path.delete('\\').tr('/', '-')
  end

  def scrub_filename(filename)
    return "Mike's Song" if /mike/i.match?(filename)
    return 'Hold Your Head Up' if /\d postgres( -)?.mp3\z/.match?(filename)
    return 'Free Bird' if /Freebird.mp3/.match?(filename)
    filename
      .gsub('.mp3', '')
      .gsub(/\AII?/, '')
      .tr('_', ' ')
  end
end
