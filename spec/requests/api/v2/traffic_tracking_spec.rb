require "rails_helper"

RSpec.describe "API v2 traffic tracking" do
  before do
    create(:show, date: "1997-11-22")
    TrafficBuffer.clear!
  end

  after { TrafficBuffer.clear! }

  def buffered
    TrafficBuffer.pending.values.first || {}
  end

  it "counts third-party calls with route pattern, ip and user agent" do
    get_api "/shows/1997-11-22", headers: { "User-Agent" => "curl/8.0" }

    expect(response).to have_http_status(:ok)
    expect(buffered).to eq(
      { client: "api", logged_in: false, route: "/shows/:date", ip: "127.0.0.1", user_agent: "curl/8.0" } => 1
    )
  end

  it "uses the forwarded ip when behind a proxy" do
    get_api "/shows/1997-11-22", headers: { "X-Forwarded-For" => "203.0.113.5" }

    expect(buffered.keys.first[:ip]).to eq("203.0.113.5")
  end

  it "prefers the cloudflare connecting ip over the proxy chain" do
    get_api "/shows/1997-11-22", headers: { "CF-Connecting-IP" => "198.51.100.9", "X-Forwarded-For" => "203.0.113.5" }

    expect(buffered.keys.first[:ip]).to eq("198.51.100.9")
  end

  it "records not found responses on matched routes" do
    get_api "/shows/1997-11-23"

    expect(response).to have_http_status(:not_found)
    expect(buffered.values.sum).to eq(1)
  end

  it "counts web client calls without ip or user agent" do
    get_api "/shows/1997-11-22", headers: { "X-Phishin-Client" => "web", "User-Agent" => "Mozilla/5.0" }

    expect(buffered).to eq(
      { client: "web", logged_in: false, route: "/shows/:date", ip: "", user_agent: "" } => 1
    )
  end

  it "flags logged in users" do
    get_api_authed create(:user), "/shows/1997-11-22", headers: { "X-Phishin-Client" => "web" }

    expect(buffered.keys.first).to include(client: "web", logged_in: true)
  end

  it "skips swagger docs" do
    get_api "/swagger_doc"

    expect(response).to have_http_status(:ok)
    expect(buffered).to be_empty
  end
end
