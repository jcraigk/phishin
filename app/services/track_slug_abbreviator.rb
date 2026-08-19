class TrackSlugAbbreviator < ApplicationService
  # Only the abbreviations TrackSlugGenerator applies. Deliberately narrow:
  # a full slug regeneration would also rewrite unrelated slugs and change
  # public URLs, so this fixes long-form slugs and nothing else.
  # Longest patterns first so nested replacements cannot corrupt each other.
  ABBREVIATIONS = {
    "she-caught-the-katy-and-left-me-a-mule-to-ride" => "she-caught-the-katy",
    "the-man-who-stepped-into-yesterday" => "tmwsiy",
    "mcgrupp-and-the-watchful-hosemasters" => "mcgrupp",
    "big-black-furry-creature-from-mars" => "bbfcfm",
    "you-enjoy-myself" => "yem",
    "hold-your-head-up" => "hyhu"
  }.freeze

  option :dry_run, default: -> { true }

  def call
    updates = collect_updates
    apply(updates) unless dry_run
    updates
  end

  private

  def collect_updates
    ABBREVIATIONS.flat_map { |long, short| updates_for(long, short) }.uniq { |u| u[:id] }
  end

  def updates_for(long, short)
    Track.includes(:show).where("slug LIKE ?", "%#{long}%").filter_map do |track|
      abbreviated = abbreviate(track.slug)
      next if abbreviated == track.slug
      next if collides?(track, abbreviated)

      {
        id: track.id,
        date: track.show.date.to_s,
        from: track.slug,
        to: abbreviated,
        rule: "#{long} -> #{short}"
      }
    end
  end

  def abbreviate(slug)
    ABBREVIATIONS.reduce(slug) { |acc, (long, short)| acc.gsub(long, short) }
  end

  # Never take a slug another track in the same show already holds.
  def collides?(track, slug)
    Track.where(show_id: track.show_id, slug:).where.not(id: track.id).exists?
  end

  def apply(updates)
    Track.transaction do
      updates.each { |u| Track.where(id: u[:id]).update_all(slug: u[:to]) }
    end
  end
end
