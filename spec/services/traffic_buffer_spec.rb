require "rails_helper"

RSpec.describe TrafficBuffer do
  let(:hit) { { client: "api", logged_in: false, route: "/shows/:date", ip: "203.0.113.5", user_agent: "curl/8.0" } }

  before { described_class.clear! }

  describe ".increment" do
    after { described_class.clear! }

    it "counts hits in redis by hour without touching postgres" do
      travel_to Time.utc(2026, 9, 16, 12, 30) do
        2.times { described_class.increment(**hit) }
      end

      expect(described_class.pending).to eq({ Time.utc(2026, 9, 16, 12) => { hit => 2 } })
      expect(TrafficCount.count).to eq(0)
    end

    it "keeps distinct combinations apart" do
      described_class.increment(**hit)
      described_class.increment(**hit, logged_in: true)
      described_class.increment(**hit, client: "web", ip: "", user_agent: "")

      expect(described_class.pending.values.first.size).to eq(3)
    end
  end

  describe ".increment when redis is down" do
    it "swallows the failure so requests are unaffected" do
      allow(Sidekiq).to receive(:redis).and_raise(RedisClient::CannotConnectError)

      expect { described_class.increment(**hit) }.not_to raise_error
    end
  end

  describe ".flush!" do
    after { described_class.clear! }

    it "moves counts into postgres and empties the buffer" do
      travel_to Time.utc(2026, 9, 16, 12, 10) do
        3.times { described_class.increment(**hit) }
      end
      travel_to Time.utc(2026, 9, 16, 13, 5) do
        described_class.increment(**hit)
      end

      expect(described_class.flush!).to eq(2)

      expect(TrafficCount.find_by(hour: Time.utc(2026, 9, 16, 12), **hit).count).to eq(3)
      expect(TrafficCount.find_by(hour: Time.utc(2026, 9, 16, 13), **hit).count).to eq(1)
      expect(described_class.pending).to eq({})
    end

    it "adds to counts already stored" do
      TrafficCount.create!(hour: Time.utc(2026, 9, 16, 12), count: 5, **hit)
      travel_to Time.utc(2026, 9, 16, 12, 45) do
        described_class.increment(**hit)
      end

      described_class.flush!

      expect(TrafficCount.find_by(hour: Time.utc(2026, 9, 16, 12), **hit).count).to eq(6)
    end

    it "does not lose hits recorded while a flush is running" do
      described_class.increment(**hit)
      allow(TrafficCount).to receive(:add_counts!).and_wrap_original do |original, *args|
        described_class.increment(**hit, route: "/years")
        original.call(*args)
      end

      described_class.flush!

      expect(described_class.pending.values.first).to eq({ hit.merge(route: "/years") => 1 })
    end

    it "returns zero when nothing is buffered" do
      expect(described_class.flush!).to eq(0)
    end
  end
end
