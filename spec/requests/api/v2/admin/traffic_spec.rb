require "rails_helper"

RSpec.describe "API v2 Admin Traffic" do
  let(:admin) { create(:user, :admin) }
  let(:admin_headers) { { "X-Auth-Token" => UserJwtService.call(admin) } }
  let(:now) { Time.zone.local(2026, 9, 17, 14, 30) }

  before { travel_to(now) }

  def usage(**attrs)
    defaults = { hour: now.beginning_of_hour, client: "api", logged_in: false, route: "/years", ip: "203.0.113.5", user_agent: "curl/8.0", count: 1 }
    TrafficCount.create!(defaults.merge(attrs))
  end

  def web(**attrs)
    usage(client: "web", ip: "", user_agent: "", **attrs)
  end

  it "requires admin" do
    get "/api/v2/admin/traffic"
    expect(response).to have_http_status(:unauthorized)
  end

  it "summarizes usage within a day window" do
    usage(count: 7)
    usage(hour: 2.days.ago.beginning_of_hour, route: "/shows/:date", ip: "198.51.100.9", user_agent: "python-requests/2.31", count: 3)
    usage(hour: 60.days.ago.beginning_of_hour, route: "/tags", ip: "192.0.2.1", user_agent: "old-bot/1.0", count: 99)
    web(route: "/shows/:date", count: 20)
    web(route: "/shows/:date", logged_in: true, count: 5)

    get "/api/v2/admin/traffic?window=30d", headers: admin_headers

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["window"]).to eq("30d")
    expect(body["bucket"]).to eq("day")
    expect(body["client"]).to be_nil
    expect(body["total"]).to eq(35)
    expect(body["series"].size).to eq(30)
    expect(body["series"].last).to eq({ "at" => now.beginning_of_day.iso8601, "count" => 32, "web" => 25, "api" => 7 })
    expect(body["clients"]).to eq({ "web" => 25, "api" => 10 })
    expect(body["logged_in"]).to eq({ "true" => 5, "false" => 30 })
    expect(body["routes"]).to eq([ { "value" => "/shows/:date", "count" => 28 }, { "value" => "/years", "count" => 7 } ])
    expect(body["ips"].map { it["value"] }).to eq([ "203.0.113.5", "198.51.100.9" ])
    expect(body["user_agents"].map { it["value"] }).to eq([ "curl/8.0", "python-requests/2.31" ])
    expect(body["distinct"]).to eq({ "routes" => 2, "ips" => 2, "user_agents" => 2 })
  end

  it "caps each breakdown at the top limit and reports the distinct count" do
    250.times { |i| usage(ip: "10.0.#{i / 250}.#{i % 250}", count: i + 1) }

    get "/api/v2/admin/traffic?window=7d", headers: admin_headers

    body = JSON.parse(response.body)
    expect(body["ips"].size).to eq(200)
    expect(body["ips"].first["count"]).to eq(250)
    expect(body["distinct"]["ips"]).to eq(250)
  end

  it "buckets by hour for short windows" do
    usage(count: 7)
    usage(hour: 3.hours.ago.beginning_of_hour, count: 2)
    usage(hour: 30.hours.ago.beginning_of_hour, count: 50)

    get "/api/v2/admin/traffic?window=12h", headers: admin_headers

    body = JSON.parse(response.body)
    expect(body["bucket"]).to eq("hour")
    expect(body["total"]).to eq(9)
    expect(body["series"].size).to eq(12)
    expect(body["series"].last).to eq({ "at" => now.beginning_of_hour.iso8601, "count" => 7, "web" => 0, "api" => 7 })
    expect(body["series"][-4]["count"]).to eq(2)
  end

  it "narrows to one client" do
    usage(count: 7)
    web(route: "/shows/:date", count: 20)

    get "/api/v2/admin/traffic?window=7d&client=web", headers: admin_headers

    body = JSON.parse(response.body)
    expect(body["client"]).to eq("web")
    expect(body["total"]).to eq(20)
    expect(body["routes"]).to eq([ { "value" => "/shows/:date", "count" => 20 } ])
    expect(body["ips"]).to eq([])
  end

  it "narrows every breakdown to one ip" do
    usage(count: 7)
    usage(ip: "198.51.100.9", route: "/shows/:date", user_agent: "python-requests/2.31", count: 3)

    get "/api/v2/admin/traffic?window=7d&ip=198.51.100.9", headers: admin_headers

    body = JSON.parse(response.body)
    expect(body["ip"]).to eq("198.51.100.9")
    expect(body["total"]).to eq(3)
    expect(body["routes"]).to eq([ { "value" => "/shows/:date", "count" => 3 } ])
    expect(body["user_agents"]).to eq([ { "value" => "python-requests/2.31", "count" => 3 } ])
  end

  it "exports the window as a downloadable json file" do
    usage(count: 7)

    get "/api/v2/admin/traffic/export?window=7d", headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(response.headers["Content-Disposition"]).to match(/attachment; filename="phishin-traffic-7d-\d{8}-\d{4}\.json"/)
    body = JSON.parse(response.body)
    expect(body["totals"]["requests"]).to eq(7)
    expect(body["api_callers"].size).to eq(1)
  end

  it "rejects unsupported windows and clients" do
    get "/api/v2/admin/traffic?window=3d", headers: admin_headers
    expect(response).to have_http_status(:bad_request)

    get "/api/v2/admin/traffic?client=bot", headers: admin_headers
    expect(response).to have_http_status(:bad_request)
  end
end
