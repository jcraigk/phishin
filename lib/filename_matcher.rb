class FilenameMatcher
  attr_reader :matches, :s_dir

  def initialize(dir)
    @s_dir     = scrub_dir_path(dir)
    unless File.directory? @s_dir
      puts "TRIED: #{@s_dir}"
      raise "Must provide a valid directory path" 
    end

    @matches  = {}
    filenames = Dir.entries(@s_dir).reject{ |e| e == '.' || e == '..' || e =~ /.txt$/ }

    filenames.each do |filename|
      s_filename = scrub_filename filename
      found      = find_match s_filename

      @matches[filename] = found
    end
    @matches = Hash[@matches.sort]
  end

  def submit_correction(filename, search_term)
    return false unless @matches.has_key? filename

    match = find_match search_term, :exact => true
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

  def find_match(q, opts={})
    if opts[:exact]
      Song.where('lower(title) = ?', q.downcase).first
    else
      Song.kinda_matching(q).first
    end
  end

  private

  def scrub_dir_path(path)
    path.gsub('\\', '').gsub('/', '-')
  end

  def scrub_filename(filename)
    if filename =~ /mike/i
      "Mike's Song"
    elsif filename =~ /\d HYHU( -)?.mp3$/
      "Hold Your Head Up"
    elsif filename =~ /Freebird.mp3/
      "Free Bird"
    else
      filename
        .gsub('.mp3', '')
        .gsub(/^II?/, '')
        .gsub('_', ' ')
    end
  end
end
