class ShowImporter::FilenameMatcher
  attr_reader :matches, :dir

  def initialize(dir)
    @dir = dir
    @matches = {}

    match_filenames_with_songs
  end

  def find_song(term, opts = {})
    return Song.where("lower(title) = ?", term.downcase).first if opts[:exact]
    Song.kinda_matching(term).first
  end

  private

  def match_filenames_with_songs
    filenames.each do |filename|
      s_filename = scrub_filename(filename)
      found = find_song(s_filename)
      @matches[filename] = found
    end

    @matches = @matches.sort.to_h
  end

  def filenames
    Dir.entries(dir).reject do |e|
      e.start_with?(".") || e =~ /.txt\z/
    end
  end

  def scrub_dir_path(path)
    path.delete("\\").tr("/", "-")
  end

  def scrub_filename(filename)
    return "Mike's Song" if /mike/i.match?(filename)
    return "Hold Your Head Up" if /\d postgres( -)?.mp3\z/.match?(filename)
    return "Free Bird" if /Freebird.mp3/.match?(filename)
    filename
      .gsub(".mp3", "")
      .gsub(/\AII?/, "")
      .tr("_", " ")
  end
end
