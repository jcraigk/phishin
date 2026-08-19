class GuestTagAuditService < ApplicationService
  # Bare first names of the band. Surnames (Gordon, Fishman, McConnell,
  # Anastasio) are deliberately absent: they appear inside real guest names
  # such as Gordon Stone, Mimi Fishman, and Dr. Jack McConnell, so matching on
  # them would flag legitimate tags.
  MEMBER = /\b(?:trey|mike|page|fish|fishman)\b/i

  # Capitalized words that begin a sentence or describe a thing rather than a
  # performer, so they must not be mistaken for a guest's name.
  NON_NAMES = /\A(?:The|With|And|A|An|No|Not|Phish|Jam|Set|First|Second|During|After|Before|
                   Features|Featuring|Performed|Played|Began|Ended|Ninja|Cosmic)\z/x

  option :dry_run, default: -> { true }

  def call
    scanned = 0
    flagged = []

    tags.find_each do |track_tag|
      scanned += 1
      notes = track_tag.notes.to_s.strip
      next if notes.blank?
      next unless notes.match?(MEMBER)
      next if names_a_guest?(notes)

      flagged << entry_for(track_tag, notes)
    end

    apply(flagged) unless dry_run

    { scanned:, flagged:, deleted: flagged.count { |e| e[:action] == :delete },
      corrected: flagged.count { |e| e[:action] == :correct } }
  end

  private

  def tags
    TrackTag.where(tag: Tag.find_by!(name: "Guest")).includes(track: :show)
  end

  # A guest is present when the note contains a capitalized name that is not a
  # band member. Possessives ("Fish's drums") describe equipment, not a player.
  def names_a_guest?(notes)
    scrubbed = notes.gsub(/\b(?:trey|mike|page|fish|fishman)'s\b/i, "")
    scrubbed.scan(/\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*/).any? do |name|
      !name.match?(/\A(?:trey|mike|page|fish|fishman)\z/i) && !name.match?(NON_NAMES)
    end
  end

  def entry_for(track_tag, notes)
    base = {
      id: track_tag.id,
      date: track_tag.track.show.date.to_s,
      title: track_tag.track.title,
      notes:
    }

    # Some notes lost their guest half to an earlier bad edit; the Phish.net
    # footnote still has it. Only substitute when we can name the guest.
    replacement = GUEST_CORRECTIONS[track_tag.id]
    return base.merge(action: :correct, replacement:) if replacement

    base.merge(action: :delete)
  end

  # Reviewed by hand: the note dropped a named guest that the source footnote
  # still records. Keyed by TrackTag id so an unrelated tag cannot be rewritten.
  GUEST_CORRECTIONS = {
    67672 => "Cosmic Country Horns"
  }.freeze

  def apply(flagged)
    TrackTag.transaction do
      flagged.each do |entry|
        record = TrackTag.find_by(id: entry[:id])
        next if record.nil?

        entry[:action] == :correct ? record.update!(notes: entry[:replacement]) : record.destroy!
      end
    end
  end
end
