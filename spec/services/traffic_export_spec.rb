require "rails_helper"

RSpec.describe TrafficExport do
  let(:now) { Time.zone.local(2026, 9, 17, 14, 30) }

  before { travel_to(now) }

  def usage(**attrs)
    defaults = { hour: now.beginning_of_hour, client: "api", logged_in: false, route: "/years", ip: "203.0.113.5", user_agent: "curl/8.0", count: 1 }
    TrafficCount.create!(defaults.merge(attrs))
  end

  describe "a mixed window" do
    subject(:export) { described_class.call(window: "7d") }

    before do
      usage(count: 7)
      usage(route: "/shows/:date", count: 2)
      usage(ip: "198.51.100.9", user_agent: "python-requests/2.31", route: "/shows/:date", count: 3)
      usage(client: "web", ip: "", user_agent: "", route: "/shows/:date", logged_in: true, count: 20)
      usage(hour: 60.days.ago.beginning_of_hour, ip: "192.0.2.1", user_agent: "old-bot/1.0", count: 99)
    end

    it "describes the window and totals" do
      expect(export[:window]).to include(key: "7d", bucket: :day)
      expect(export[:totals]).to eq(requests: 32, web: 20, api: 12, logged_in: 20, anonymous: 12)
      expect(export[:notes]).to be_an(Array)
    end

    it "includes a per-bucket series split by client" do
      expect(export[:series].size).to eq(7)
      expect(export[:series].last).to include(count: 32, web: 20, api: 12)
    end

    it "lists every route with a client split" do
      expect(export[:routes]).to eq([
        { route: "/shows/:date", count: 25, web: 20, api: 5 },
        { route: "/years", count: 7, web: 0, api: 7 }
      ])
    end

    it "lists every api ip and user agent" do
      expect(export[:ips]).to eq([
        { ip: "203.0.113.5", count: 9, user_agents: 1, routes: 2 },
        { ip: "198.51.100.9", count: 3, user_agents: 1, routes: 1 }
      ])
      expect(export[:user_agents]).to eq([
        { user_agent: "curl/8.0", count: 9, ips: 1 },
        { user_agent: "python-requests/2.31", count: 3, ips: 1 }
      ])
    end

    it "groups api callers by ip and user agent with routes" do
      expect(export[:api_callers].first).to eq(
        ip: "203.0.113.5", user_agent: "curl/8.0", count: 9, routes: { "/years" => 7, "/shows/:date" => 2 }
      )
    end
  end

  it "honours client and ip filters" do
    usage(count: 7)
    usage(ip: "198.51.100.9", count: 3)
    usage(client: "web", ip: "", user_agent: "", count: 20)

    export = described_class.call(window: "24h", client: "api", ip: "198.51.100.9")

    expect(export[:filters]).to eq(client: "api", ip: "198.51.100.9")
    expect(export[:totals][:requests]).to eq(3)
    expect(export[:api_callers].size).to eq(1)
  end
end
