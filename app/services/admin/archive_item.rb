# An archive.org item as an ingest source. Metadata comes from the JSON
# endpoint; the audio comes down with curl, which copes with the intermittent
# 5xx archive.org mirrors throw where a single Typhoeus request would not.
class Admin::ArchiveItem
  METADATA_URL = "https://archive.org/metadata/%s".freeze
  DOWNLOAD_URL = "https://archive.org/download/%s/%s".freeze
  DETAILS_URL = "https://archive.org/details/%s".freeze

  # Lossless first. An item that offers both flac and the derived mp3 is
  # ingested from the flac; the mp3 list is only used when that is all there is.
  LOSSLESS = [ "Flac", "Shorten", "WAVE", "AIFF" ].freeze
  LOSSY = [ "VBR MP3", "MP3", "64Kbps MP3", "128Kbps MP3" ].freeze
  EXTENSIONS = { "Flac" => "flac", "Shorten" => "shn", "WAVE" => "wav", "AIFF" => "aiff" }.freeze

  class NotFoundError < StandardError; end
  class NoAudioError < StandardError; end
  class DownloadError < StandardError; end

  attr_reader :identifier

  def initialize(identifier)
    @identifier = identifier.to_s.strip
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
    files.map do |file|
      dest = File.join(dir, file["name"])
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

  # File names carry spaces and punctuation; curl sends the URL as given, so
  # the path is escaped the way a browser would.
  def fetch(name, dest)
    url = format(DOWNLOAD_URL, identifier, URI::RFC2396_PARSER.escape(name))
    tmp = "#{dest}.part"
    3.times do |attempt|
      break if system("curl", "-sfL", "--retry", "2", "-o", tmp, url)
      raise DownloadError, "download of #{name} failed after 3 attempts" if attempt == 2
    end
    File.rename(tmp, dest)
  end
end
