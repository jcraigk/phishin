class Admin::ArchiveItem
  METADATA_URL = "https://archive.org/metadata/%s".freeze
  DOWNLOAD_URL = "https://archive.org/download/%s/%s".freeze
  DETAILS_URL = "https://archive.org/details/%s".freeze

  LOSSLESS = [ "Flac", "24bit Flac", "Shorten", "WAVE", "AIFF", "Apple Lossless Audio" ].freeze
  LOSSY = [ "VBR MP3", "MP3", "64Kbps MP3", "128Kbps MP3" ].freeze

  IDENTIFIER = /\A[A-Za-z0-9._-]+\z/

  class NotFoundError < StandardError; end
  class NoAudioError < StandardError; end
  class DownloadError < StandardError; end

  attr_reader :identifier

  def self.parse_identifier(input)
    text = input.to_s.strip
    text[%r{archive\.org/(?:details|download)/([A-Za-z0-9._-]+)}, 1] || text
  end

  def initialize(identifier)
    @identifier = self.class.parse_identifier(identifier)
    raise ArgumentError, "invalid archive.org identifier" unless @identifier.match?(IDENTIFIER)
  end

  def date
    raw = metadata.dig("metadata", "date").to_s[/\d{4}-\d{2}-\d{2}/]
    raw || identifier[/\d{4}-\d{2}-\d{2}/]
  end

  def files
    @files ||= begin
      chosen = LOSSLESS.flat_map { by_format(it) }
      chosen = LOSSY.flat_map { by_format(it) } if chosen.empty?
      raise NoAudioError, "#{identifier} has no audio files" if chosen.empty?
      chosen.sort_by { it["name"] }
    end
  end

  def description
    html = metadata.dig("metadata", "description")
    html = html.join("\n") if html.is_a?(Array)
    return "" if html.blank?
    html.gsub(%r{<br\s*/?>|</p>}i, "\n").gsub(/<[^>]+>/, "").gsub(/\n{2,}/, "\n").strip
  end

  def details_url
    format(DETAILS_URL, identifier)
  end

  def download_to(dir)
    FileUtils.mkdir_p(dir)
    files.each_with_index.map do |file, index|
      yield(file["name"], index, files.size) if block_given?
      dest = File.join(dir, File.basename(file["name"]))
      fetch(file["name"], dest)
      dest
    end
  end

  private

  def by_format(name)
    metadata.fetch("files", []).select { it["format"] == name }
  end

  def metadata
    @metadata ||= begin
      response = Typhoeus.get(format(METADATA_URL, identifier), followlocation: true)
      data = response.code == 200 ? JSON.parse(response.body) : {}
      raise NotFoundError, "archive.org has no item #{identifier}" if data["files"].blank?
      data
    rescue JSON::ParserError
      raise NotFoundError, "archive.org returned no metadata for #{identifier}"
    end
  end

  def fetch(name, dest)
    url = format(DOWNLOAD_URL, identifier, URI::RFC2396_PARSER.escape(name))
    tmp = "#{dest}.part"
    3.times do |attempt|
      break if system("curl", "-sfL", "--globoff", "--retry", "2", "-o", tmp, url)
      if attempt == 2
        FileUtils.rm_f(tmp)
        raise DownloadError, "download of #{name} failed after 3 attempts"
      end
    end
    File.rename(tmp, dest)
  end
end
