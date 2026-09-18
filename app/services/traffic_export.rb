class TrafficExport < ApplicationService
  option :window
  option :client, optional: true
  option :ip, optional: true

  NOTES = [
    "Aggregated request counts for phish.in, bucketed by hour at collection time.",
    "client: 'web' is the phish.in React frontend calling its own API; 'api' is any other caller (scripts, apps, bots).",
    "logged_in counts requests that carried a valid user token.",
    "Web rows carry no ip or user_agent, so ips, user_agents and api_callers cover API traffic only.",
    "series buckets are in the site's local time zone; counts are request totals per bucket.",
    "api_callers groups API traffic by ip and user_agent with a per-route breakdown."
  ].freeze

  def call
    {
      generated_at: Time.current.iso8601,
      site: App.base_url,
      time_zone: Time.zone.name,
      window: { key: window, from: from.iso8601, to: Time.current.iso8601, bucket: },
      filters: { client: client.presence, ip: ip.presence },
      notes: NOTES,
      totals:,
      series:,
      routes: routes_breakdown,
      ips: ips_breakdown,
      user_agents: user_agents_breakdown,
      api_callers:
    }
  end

  private

  def length_and_bucket
    TrafficCount::WINDOWS.fetch(window)
  end

  def bucket
    length_and_bucket.last
  end

  def from
    @from ||= TrafficCount.window_start(window)
  end

  def scope
    @scope ||= begin
      s = TrafficCount.where(hour: from..)
      s = s.where(client:) if client.present?
      s = s.where(ip:) if ip.present?
      s
    end
  end

  def api_scope
    scope.where(client: "api")
  end

  def totals
    by_client = scope.group(:client).sum(:count)
    by_login = scope.group(:logged_in).sum(:count)
    {
      requests: scope.sum(:count),
      web: by_client["web"] || 0,
      api: by_client["api"] || 0,
      logged_in: by_login[true] || 0,
      anonymous: by_login[false] || 0
    }
  end

  def series
    TrafficCount.series(scope, from, bucket)
  end

  def routes_breakdown
    rows = Hash.new { |h, k| h[k] = { route: k, count: 0, web: 0, api: 0 } }
    scope.group(:route, :client).sum(:count).each do |(route, client_name), count|
      rows[route][:count] += count
      rows[route][client_name.to_sym] += count
    end
    rows.values.sort_by { |r| [ -r[:count], r[:route] ] }
  end

  def ips_breakdown
    counts = api_scope.group(:ip).sum(:count)
    agents = api_scope.group(:ip).distinct.count(:user_agent)
    routes = api_scope.group(:ip).distinct.count(:route)
    counts.map { |value, count| { ip: value, count:, user_agents: agents[value], routes: routes[value] } }
          .sort_by { |r| [ -r[:count], r[:ip] ] }
  end

  def user_agents_breakdown
    counts = api_scope.group(:user_agent).sum(:count)
    ips = api_scope.group(:user_agent).distinct.count(:ip)
    counts.map { |value, count| { user_agent: value, count:, ips: ips[value] } }
          .sort_by { |r| [ -r[:count], r[:user_agent] ] }
  end

  def api_callers
    callers = Hash.new { |h, k| h[k] = { ip: k[0], user_agent: k[1], count: 0, routes: Hash.new(0) } }
    api_scope.group(:ip, :user_agent, :route).sum(:count).each do |(ip_value, agent, route), count|
      caller = callers[[ ip_value, agent ]]
      caller[:count] += count
      caller[:routes][route] += count
    end
    callers.values.each { |c| c[:routes] = c[:routes].sort_by { |route, count| [ -count, route ] }.to_h }
    callers.values.sort_by { |c| [ -c[:count], c[:ip], c[:user_agent] ] }
  end
end
