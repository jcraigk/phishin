class Admin::UploadDateSniffer
  MAX_TEXT_BYTES = 1.megabyte

  ISO = /((?:19[89]|20[0-4])\d)[-._ ]?(0[1-9]|1[0-2])[-._ ]?(0[1-9]|[12]\d|3[01])/
  US = %r{\b(0?[1-9]|1[0-2])/(0?[1-9]|[12]\d|3[01])/((?:19|20)\d{2})\b}
  MONTH_NAME = /\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),?\s+((?:19|20)\d{2})\b/i

  def self.call(blobs)
    new(blobs).call
  end

  def initialize(blobs)
    @blobs = blobs
  end

  def call
    chunks.each do |chunk|
      date = detect(chunk)
      return date if date
    end
    nil
  end

  private

  def chunks
    texts = @blobs.select { text?(it) }.map { safe_download(it) }.compact
    texts + [ @blobs.map { Show.original_filename(it) }.join("\n") ]
  end

  def text?(blob)
    blob.content_type.to_s.start_with?("text/") ||
      Show.original_filename(blob).to_s.downcase.end_with?(".txt")
  end

  def safe_download(blob)
    return nil if blob.byte_size > MAX_TEXT_BYTES
    blob.download.force_encoding(Encoding::UTF_8).scrub
  rescue StandardError
    nil
  end

  def detect(chunk)
    if (m = chunk.match(ISO))
      return build(m[1], m[2], m[3])
    end
    if (m = chunk.match(US))
      return build(m[3], m[1], m[2])
    end
    if (m = chunk.match(MONTH_NAME))
      return build(m[3], Date::MONTHNAMES.index(m[1].capitalize), m[2])
    end
    nil
  end

  def build(year, month, day)
    Date.new(year.to_i, month.to_i, day.to_i)
  rescue Date::Error
    nil
  end
end
