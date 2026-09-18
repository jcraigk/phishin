require "rails_helper"

RSpec.describe TrafficCount do
  let(:key) do
    { client: "api", logged_in: false, route: "/shows/:date", ip: "203.0.113.5", user_agent: "curl/8.0" }
  end
  let(:hour) { Time.utc(2026, 9, 16, 14) }

  describe ".add_counts!" do
    it "creates rows on first sight" do
      described_class.add_counts!(hour, { key => 4 })

      expect(described_class.find_by(hour:, **key).count).to eq(4)
    end

    it "adds to existing rows" do
      described_class.add_counts!(hour, { key => 4 })
      described_class.add_counts!(hour, { key => 3 })

      expect(described_class.count).to eq(1)
      expect(described_class.first.count).to eq(7)
    end

    it "keeps separate rows per hour, client, login state, route, ip and user agent" do
      described_class.add_counts!(hour, { key => 1, key.merge(ip: "198.51.100.9") => 1, key.merge(logged_in: true) => 1 })
      described_class.add_counts!(hour + 1.hour, { key => 1 })

      expect(described_class.count).to eq(4)
    end

    it "truncates long user agents" do
      described_class.add_counts!(hour, { key.merge(user_agent: "x" * 1000) => 1 })

      expect(described_class.first.user_agent.length).to eq(described_class::USER_AGENT_MAX_LENGTH)
    end

    it "does nothing with an empty batch" do
      expect { described_class.add_counts!(hour, {}) }.not_to change(described_class, :count)
    end
  end
end
