# frozen_string_literal: true
class DurationFormatter
  attr_reader :duration, :seconds, :minutes, :hours, :days, :style

  def initialize(duration, style = nil)
    @duration = duration
    @style = style.in?(%w[colon letters]) ? style : 'colon'
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
    if days.positive?
      lettered_days_hours_mins
    elsif hours.positive?
      lettered_hours_mins
    else
      lettered_mins_seconds
    end
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

  def lettered_days_hours_mins
    format(
      '%<days>dd %<hours>dh %<minutes>dm',
      days: days,
      hours: hours,
      minutes: minutes
    )
  end

  def lettered_hours_mins
    format(
      '%<hours>dh %<minutes>dm',
      hours: hours,
      minutes: minutes
    )
  end

  def lettered_mins_seconds
    format(
      '%<minutes>dm %<seconds>ds',
      minutes: minutes,
      seconds: seconds
    )
  end

  def colon_mins_seconds
    format(
      '%<minutes>d:%<seconds>02d',
      minutes: minutes,
      seconds: seconds
    )
  end

  def colon_days_hours_mins_seconds
    format(
      '%<days>d:%<hours>02d:%<minutes>02d:%<seconds>02d',
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds
    )
  end

  def colon_hours_mins_seconds
    format(
      '%<hours>d:%<minutes>02d:%<seconds>02d',
      hours: hours,
      minutes: minutes,
      seconds: seconds
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
