class TrafficBuffer
  PREFIX = "traffic:#{Rails.env}".freeze
  SEPARATOR = "\x1f".freeze
  FIELDS = %i[client logged_in route ip user_agent].freeze

  class << self
    def increment(client:, logged_in:, route:, ip:, user_agent:)
      field = [ client, logged_in ? 1 : 0, route, ip, user_agent ].join(SEPARATOR)
      redis { |conn| conn.call("HINCRBY", buffer_key(Time.current), field, 1) }
    rescue RedisClient::Error => e
      Rails.logger.warn("TrafficBuffer increment failed: #{e.message}")
      nil
    end

    def flush!
      keys = redis { |conn| conn.call("KEYS", "#{PREFIX}:buffer:*") } + redis { |conn| conn.call("KEYS", "#{PREFIX}:flushing:*") }
      keys.sort.uniq.sum { |key| flush_key(key) }
    end

    def pending
      redis { |conn| conn.call("KEYS", "#{PREFIX}:buffer:*") }.sort.to_h do |key|
        hash = redis { |conn| conn.call("HGETALL", key) }
        [ hour_from(key), decode(hash) ]
      end
    end

    def clear!
      keys = redis { |conn| conn.call("KEYS", "#{PREFIX}:*") }
      redis { |conn| conn.call("DEL", *keys) } if keys.any?
    end

    private

    def flush_key(key)
      flushing_key = key.sub(":buffer:", ":flushing:")
      if key.include?(":buffer:")
        renamed = redis { |conn| conn.call("RENAMENX", key, flushing_key) }
        return 0 if renamed.zero?
      end
      hash = redis { |conn| conn.call("HGETALL", flushing_key) }
      counts = decode(hash)
      TrafficCount.add_counts!(hour_from(key), counts)
      redis { |conn| conn.call("DEL", flushing_key) }
      counts.size
    end

    def decode(hash)
      hash.to_h do |field, count|
        client, logged_in, route, ip, user_agent = field.split(SEPARATOR, FIELDS.size)
        [ { client:, logged_in: logged_in == "1", route:, ip: ip.to_s, user_agent: user_agent.to_s }, count.to_i ]
      end
    end

    def buffer_key(time)
      "#{PREFIX}:buffer:#{time.utc.beginning_of_hour.to_i}"
    end

    def hour_from(key)
      Time.zone.at(key.split(":").last.to_i).utc
    end

    def redis(&)
      Sidekiq.redis(&)
    end
  end
end
