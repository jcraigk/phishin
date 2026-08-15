# Turns a raw tagin spreadsheet cell into the value the database would hold.
#
# TrackTagSyncService writes sheet values through sanitization, and TrackTag
# normalizes notes again on assignment. The drift report has to reproduce both
# steps or it reports formatting artifacts as content drift: a note ending in a
# period, or holding a curly quote or an HTML entity, differs from its own
# synced copy until the same transformations are applied to it.
#
# Both the sync and the report call this class so the two cannot drift apart.
class TaginRowNormalizer
  include ActionView::Helpers::SanitizeHelper

  MOJIBAKE_MARKERS = /√[°©≠≥∫±ºÅâçìöÑú]|‚Ä[îìúùòô¶¢]|¬[©®∞]/

  class << self
    delegate :sanitize_str, :normalized_notes, :seconds_or_nil, to: :new
  end

  def sanitize_str(str)
    return if str.nil?
    sanitize(repair_mojibake(str).gsub(/[”“]/, '"').gsub(/[‘’]/, "'"))
  end

  # The value TrackTag#notes holds after a sync writes this cell: sanitized,
  # then run through the model's own normalization.
  def normalized_notes(str)
    sanitized = sanitize_str(str)
    return if sanitized.nil?
    TrackTag.new(notes: sanitized).notes
  end

  # Sheet timestamps are "mm:ss"; the column stores seconds.
  def seconds_or_nil(str)
    return if str.blank?
    min, sec = str.split(":")
    (min.to_i * 60) + sec.to_i
  end

  private

  def repair_mojibake(str)
    return str unless str.match?(MOJIBAKE_MARKERS)
    str.encode(Encoding::MACROMAN).force_encoding(Encoding::UTF_8)
  rescue Encoding::UndefinedConversionError
    str
  end
end
