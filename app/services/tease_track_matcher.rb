# Resolves a Phish.net song label ("Tweezer", "Harry Hood") to the tracks of a show
# that can host the tease. Returns every track in the best-matching tier, in setlist
# order, so callers can check all same-title tracks for an existing row and fall
# back to the earliest one when proposing.
class TeaseTrackMatcher < ApplicationService
  param :show
  param :labels

  def call
    keys = Array(labels).map { |label| normalize(label) }.reject(&:blank?).uniq
    return [] if keys.empty?

    tracks = show.tracks.sort_by(&:position)
    keys.each do |key|
      TIERS.each do |tier|
        matches = tracks.select { |track| send(tier, track, key) }
        return matches if matches.any?
      end
    end
    []
  end

  private

  TIERS = %i[exact_title? sandwich_segment? title_includes? label_includes?].freeze

  def exact_title?(track, key)
    normalize(track.title) == key
  end

  # "Tweezer > Manteca > Tweezer" hosts a "Tweezer" tease; "Tweezer Reprise" does not.
  def sandwich_segment?(track, key)
    track.title.split(/\s*>\s*/).any? { |segment| normalize(segment) == key }
  end

  def title_includes?(track, key)
    normalize(track.title).include?(key)
  end

  def label_includes?(track, key)
    title = normalize(track.title)
    title.present? && key.include?(title)
  end

  def normalize(str)
    CGI.unescapeHTML(str.to_s).downcase.gsub(/[^a-z0-9 ]/, "").squish
  end
end
