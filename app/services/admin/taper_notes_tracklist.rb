module Admin::TaperNotesTracklist
  DISC_HEADER = /\A\s*(?:disc|cd)\s*#?(\d+)\b/i
  EXPLICIT = /\Ad(\d+)t(\d+)\z/i
  EXPLICIT_LINE = /\A\s*d(\d+)\s*t(\d+)[\s.):-]+(.+)\z/i
  NUMBERED_LINE = /\A\s*t?(\d{1,2})[\s.):-]+(.+)\z/

  def self.call(notes)
    mapping = {}
    disc = nil
    notes.to_s.each_line.map(&:chomp).each do |line|
      if (header = line.match(DISC_HEADER))
        disc = header[1].to_i
        next
      end
      if (explicit = line.match(EXPLICIT_LINE))
        mapping[key(explicit[1], explicit[2])] = clean(explicit[3])
        next
      end
      next if disc.nil?
      if (numbered = line.match(NUMBERED_LINE))
        title = clean(numbered[2])
        mapping[key(disc, numbered[1])] = title if title =~ /[a-z]/i
      end
    end
    mapping
  end

  def self.key(disc, track)
    format("d%dt%02d", disc.to_i, track.to_i)
  end

  def self.key_for(filename)
    match = File.basename(filename, ".*").match(/d(\d+)\D{0,2}t(\d+)/i)
    match && key(match[1], match[2])
  end

  def self.clean(title)
    title.strip.sub(/[\s>,*-]+\z/, "").strip
  end
end
