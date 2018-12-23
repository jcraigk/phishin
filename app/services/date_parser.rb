# frozen_string_literal: true
class DateParser
  attr_reader :str, :date_parts

  def initialize(str)
    @str = str
  end

  def call
    return false unless str_matches_short_date? ||
                        str_matches_year_at_end? ||
                        str_matches_db_date?
    Date.parse(date_parts.join('-')).strftime('%Y-%m-%d')
  end

  private

  # 10/31/95, 10-31-95
  def str_matches_short_date?
    return false unless str =~ %r{\A(\d{1,2})(\-|\/)(\d{1,2})(\-|\/)(\d{1,2})\z}
    r = Regexp.last_match
    year = r[5]
    zero = (year.size == 1 ? '0' : '')
    year = (year.to_i > 70 ? "19#{zero}#{year}" : "20#{zero}#{year}")
    @date_parts = [year, r[1], r[3]]
  end

  # 10-31-1995, 10/31/1995
  def str_matches_year_at_end?
    return false unless str =~ %r{\A(\d{1,2})(\-|\/)(\d{1,2})(\-|\/)(\d{1,4})\z}
    r = Regexp.last_match
    @date_parts = [r[5], r[1], r[3]]
  end

  # 1995-10-31
  def str_matches_db_date?
    return false unless str =~ %r{\A(\d{4})(\-|\/)(\d{1,2})(\-|\/)(\d{1,2})\z}
    r = Regexp.last_match
    @date_parts = [r[1], r[3], r[5]]
  end
end
