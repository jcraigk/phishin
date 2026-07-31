module NormalizesNotes
  extend ActiveSupport::Concern

  # Repeated decoding handles double-encoded values like &amp;amp;
  def self.decode_html_entities(text)
    loop do
      decoded = CGI.unescapeHTML(text)
      return text if decoded == text
      text = decoded
    end
  end

  included do
    # Decode HTML entities, then strip the trailing period from
    # single-sentence notes; leave multi-sentence notes, ellipses,
    # and other punctuation alone
    normalizes :notes, with: lambda { |notes|
      notes = NormalizesNotes.decode_html_entities(notes).strip
      next notes unless notes.match?(/(?<!\.)\.\z/)
      next notes if notes.delete_suffix(".").match?(/\.\s/)
      notes.delete_suffix(".")
    }
  end
end
