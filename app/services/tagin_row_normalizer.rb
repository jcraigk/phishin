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

  def normalized_notes(str)
    sanitized = sanitize_str(str)
    return if sanitized.nil?
    TrackTag.new(notes: sanitized).notes
  end

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
