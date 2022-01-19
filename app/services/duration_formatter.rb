# frozen_string_literal: true
class DurationFormatter
  attr_reader :duration, :seconds, :minutes, :hours, :days, :style

  def initialize(duration, style = nil)
    @duration = duration || 0
    @style = style.in?(%w[colons letters]) ? style : 'colons'
  end

  def call
    extract_timeframes
    format_as_string
  end

  private

  def format_as_string
    if style == 'letters'
      format_with_letters
    else
      format_with_colons
    end
  end

  def format_with_letters
    return lettered_days_hours_mins_seconds if days.positive?
    return lettered_hours_mins if hours.positive?
    lettered_mins_seconds
  end

  def format_with_colons
    if days.positive?
      colon_days_hours_mins_seconds
    elsif hours.positive?
      colon_hours_mins_seconds
    else
      colon_mins_seconds
    end
  end

  def lettered_days_hours_mins_seconds
    format(
      '%<days>dd %<hours>dh %<minutes>dm %<seconds>ds',
      days:,
      hours:,
      minutes:,
      seconds:
    )
  end

  def lettered_hours
    format('%<hours>dh', hours:)
  end

  def lettered_hours_mins
    return lettered_hours if minutes.zero?
    format('%<hours>dh %<minutes>dm', hours:, minutes:)
  end

  def lettered_mins
    format('%<minutes>dm', minutes:)
  end

  def lettered_mins_seconds
    if seconds.zero?
      return '0s' if minutes.zero?
      return lettered_mins
    end
    format('%<minutes>dm %<seconds>ds', minutes:, seconds:)
  end

  def colon_mins_seconds
    format('%<minutes>d:%<seconds>02d', minutes:, seconds:)
  end

  def colon_days_hours_mins_seconds
    format(
      '%<days>d:%<hours>02d:%<minutes>02d:%<seconds>02d',
      days:,
      hours:,
      minutes:,
      seconds:
    )
  end

  def colon_hours_mins_seconds
    format(
      '%<hours>d:%<minutes>02d:%<seconds>02d',
      hours:,
      minutes:,
      seconds:
    )
  end

  def extract_timeframes
    x = duration / 1000
    @seconds = x % 60
    x /= 60
    @minutes = x % 60
    x /= 60
    @hours = x % 24
    x /= 24
    @days = x
  end
end
