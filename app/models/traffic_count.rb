class TrafficCount < ApplicationRecord
  USER_AGENT_MAX_LENGTH = 255
  CLIENTS = %w[web api].freeze
  KEY_COLUMNS = %i[hour client logged_in route ip user_agent].freeze
  WINDOWS = {
    "1h" => [ 1.hour, :hour ],
    "12h" => [ 12.hours, :hour ],
    "24h" => [ 24.hours, :hour ],
    "7d" => [ 7.days, :day ],
    "30d" => [ 30.days, :day ],
    "90d" => [ 90.days, :day ],
    "365d" => [ 365.days, :day ]
  }.freeze

  validates :hour, :client, :route, presence: true
  validates :client, inclusion: { in: CLIENTS }

  def self.add_counts!(hour, counts)
    return if counts.empty?
    now = Time.current
    rows = counts.map do |key, count|
      key.merge(
        hour:,
        user_agent: key[:user_agent].to_s.first(USER_AGENT_MAX_LENGTH),
        count:,
        created_at: now,
        updated_at: now
      )
    end
    upsert_all(
      rows,
      unique_by: KEY_COLUMNS,
      on_duplicate: Arel.sql("count = traffic_counts.count + EXCLUDED.count, updated_at = EXCLUDED.updated_at")
    )
  end

  def self.window_start(window)
    length, bucket = WINDOWS.fetch(window)
    if bucket == :hour
      (Time.current - length + 1.hour).beginning_of_hour
    else
      (Time.current - length + 1.day).beginning_of_day
    end
  end

  def self.truncate_to(time, bucket)
    bucket == :hour ? time.in_time_zone.beginning_of_hour : time.in_time_zone.beginning_of_day
  end

  def self.series(scope, from, bucket)
    step = bucket == :hour ? 1.hour : 1.day
    counts = Hash.new { |h, k| h[k] = Hash.new(0) }
    scope.group(:hour, :client).sum(:count).each do |(hour, client), count|
      counts[truncate_to(hour, bucket)][client] += count
    end
    last = truncate_to(Time.current, bucket)
    (0..).lazy.map { |i| from + i * step }.take_while { |at| at <= last }.map do |at|
      by_client = counts[at]
      { at: at.iso8601, count: by_client.values.sum, web: by_client["web"], api: by_client["api"] }
    end.to_a
  end
end
