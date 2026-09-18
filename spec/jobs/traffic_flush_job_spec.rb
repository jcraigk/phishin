require "rails_helper"

RSpec.describe TrafficFlushJob do
  before { TrafficBuffer.clear! }
  after { TrafficBuffer.clear! }

  it "writes buffered counts to postgres" do
    travel_to Time.utc(2026, 9, 16, 12, 20) do
      TrafficBuffer.increment(client: "api", logged_in: false, route: "/years", ip: "203.0.113.5", user_agent: "curl/8.0")
    end

    described_class.new.perform

    expect(TrafficCount.first).to have_attributes(
      hour: Time.utc(2026, 9, 16, 12), client: "api", logged_in: false, route: "/years",
      ip: "203.0.113.5", user_agent: "curl/8.0", count: 1
    )
  end
end
