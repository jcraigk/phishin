require "rails_helper"

RSpec.describe McpToolCall do
  describe "validations" do
    it { is_expected.to validate_presence_of(:tool_name) }
  end

  describe "scopes" do
    let!(:old_call) { create(:mcp_tool_call, created_at: 1.week.ago) }
    let!(:recent_call) { create(:mcp_tool_call, created_at: 1.hour.ago) }
    let!(:failed_call) { create(:mcp_tool_call, :failed, created_at: 30.minutes.ago) }
    let!(:search_call) { create(:mcp_tool_call, :search, created_at: 10.minutes.ago) }

    describe ".recent" do
      it "orders by created_at descending" do
        recent = described_class.where(id: [old_call.id, recent_call.id, failed_call.id, search_call.id]).recent
        expect(recent.first).to eq(search_call)
      end
    end

    describe ".by_tool" do
      it "filters by tool name" do
        expect(described_class.by_tool("stats")).to include(old_call, recent_call, failed_call)
        expect(described_class.by_tool("search")).to include(search_call)
      end
    end

    describe ".successful" do
      it "returns calls without errors" do
        expect(described_class.successful).to include(recent_call)
        expect(described_class.successful).not_to include(failed_call)
      end
    end

    describe ".failed" do
      it "returns calls with errors" do
        expect(described_class.failed).to include(failed_call)
        expect(described_class.failed).not_to include(recent_call)
      end
    end

    describe ".since" do
      it "filters by time" do
        expect(described_class.since(1.day.ago)).to include(recent_call, failed_call)
        expect(described_class.since(1.day.ago)).not_to include(old_call)
      end
    end
  end

  describe ".log_call" do
    let(:result) { { songs: [{ song: "Tweezer", gap: 50 }], latest_show_date: "2023-12-01" } }

    it "creates a log entry" do
      expect {
        described_class.log_call(
          tool_name: "stats",
          parameters: { stat_type: "gaps", min_gap: 50 },
          result: result,
          duration_ms: 150
        )
      }.to change(described_class, :count).by(1)
    end

    it "stores parameters as JSON" do
      log = described_class.log_call(
        tool_name: "stats",
        parameters: { stat_type: "gaps", min_gap: 50, song_slug: "tweezer" }
      )

      expect(log.parameters).to eq({
        "stat_type" => "gaps",
        "min_gap" => 50,
        "song_slug" => "tweezer"
      })
    end

    it "extracts result count from arrays" do
      log = described_class.log_call(
        tool_name: "stats",
        parameters: {},
        result: result
      )

      expect(log.result_count).to eq(1)
    end

    it "captures error messages" do
      log = described_class.log_call(
        tool_name: "stats",
        parameters: { song_slug: "nonexistent" },
        result: { error: "Song not found" }
      )

      expect(log.error_message).to eq("Song not found")
    end

    it "handles logging failures gracefully" do
      allow(described_class).to receive(:create!).and_raise(StandardError.new("DB error"))

      expect {
        described_class.log_call(tool_name: "test", result: {})
      }.not_to raise_error
    end

    it "works with different tool names" do
      log = described_class.log_call(
        tool_name: "search",
        parameters: { query: "madison square garden", scope: "venues" }
      )

      expect(log.tool_name).to eq("search")
      expect(log.parameters["query"]).to eq("madison square garden")
    end
  end

  describe ".build_result_summary" do
    it "extracts keys from result hash" do
      result = { songs: [], latest_show_date: "2023-12-01" }
      summary = described_class.build_result_summary(result)

      expect(summary[:keys]).to contain_exactly("songs", "latest_show_date")
    end

    it "captures errors" do
      result = { error: "Something went wrong" }
      summary = described_class.build_result_summary(result)

      expect(summary[:error]).to eq("Something went wrong")
    end

    it "returns empty hash for non-hash results" do
      expect(described_class.build_result_summary(nil)).to eq({})
      expect(described_class.build_result_summary("string")).to eq({})
    end
  end

  describe ".extract_result_count" do
    it "counts first array found in result" do
      result = { songs: [1, 2, 3] }
      expect(described_class.extract_result_count(result)).to eq(3)
    end

    it "works with any array key" do
      result = { custom_results: [1, 2] }
      expect(described_class.extract_result_count(result)).to eq(2)
    end

    it "returns nil for non-countable results" do
      result = { message: "success" }
      expect(described_class.extract_result_count(result)).to be_nil
    end

    it "returns nil for non-hash results" do
      expect(described_class.extract_result_count(nil)).to be_nil
    end
  end

  describe "#successful?" do
    it "returns true when no error" do
      call = build(:mcp_tool_call)
      expect(call.successful?).to be true
    end

    it "returns false when error present" do
      call = build(:mcp_tool_call, :failed)
      expect(call.successful?).to be false
    end
  end

  describe "#failed?" do
    it "returns false when no error" do
      call = build(:mcp_tool_call)
      expect(call.failed?).to be false
    end

    it "returns true when error present" do
      call = build(:mcp_tool_call, :failed)
      expect(call.failed?).to be true
    end
  end
end
