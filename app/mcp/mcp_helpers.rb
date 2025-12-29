module McpHelpers
  module_function

  def base_url
    App.base_url
  end

  def cache_key_for_resource(resource_name, identifier)
    "mcp/#{resource_name}/#{identifier}"
  end

  def cache_key_for_collection(resource_name, params)
    "mcp/#{resource_name}?#{params.compact.to_query}"
  end

  def cache_key_for_custom(path)
    "mcp/#{path}"
  end

  def show_url(date)
    "#{base_url}/#{date}"
  end

  def song_url(slug)
    "#{base_url}/songs/#{slug}"
  end

  def track_url(date, track_slug)
    "#{base_url}/#{date}/#{track_slug}"
  end

  def year_url(period)
    "#{base_url}/#{period}"
  end

  def format_duration(ms)
    return "0:00" unless ms&.positive?

    total_seconds = ms / 1000
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    seconds = total_seconds % 60

    if hours > 0
      "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{seconds.to_s.rjust(2, '0')}"
    else
      "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
    end
  end
end
