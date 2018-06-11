# frozen_string_literal: true
class DateParserService
  attr_reader :str

  def initialize(str)
    @str = str
  end

  def parse
    year, month, day = nil
    # handle 2-digit year as in 3/11/90
    if str =~ %r{\A(\d{1,2})(\-|\/)(\d{1,2})(\-|\/)(\d{1,2})\z}
      year = Regexp.last_match[5]
      zero = (year.size == 1 ? '0' : '')
      year = (year.to_i > 70 ? "19#{zero}#{year}" : "20#{zero}#{year}")
      month = Regexp.last_match[1]
      day = Regexp.last_match[3]
    elsif str =~ %r{\A(\d{1,2})(\-|\/)(\d{1,2})(\-|\/)(\d{1,4})\z}
      year = Regexp.last_match[5]
      month = Regexp.last_match[1]
      day = Regexp.last_match[3]
    elsif str =~ %r{\A(\d{4})(\-|\/)(\d{1,2})(\-|\/)(\d{1,2})\z}
      year = Regexp.last_match[1]
      month = Regexp.last_match[3]
      day = Regexp.last_match[5]
    else
      return false
    end

    Date.parse([year, month, day].join('-')).strftime('%Y-%m-%d')
  end
end
