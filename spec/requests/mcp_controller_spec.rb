require "rails_helper"

RSpec.describe "MCP Controller" do
  let(:headers) { { "Content-Type" => "application/json" } }

  def json_rpc_request(rpc_method:, params: {}, id: 1)
    { jsonrpc: "2.0", method: rpc_method, params:, id: }.to_json
  end

  describe "POST /mcp" do
    it "returns Mcp-Session-Id header" do
      post("/mcp", params: json_rpc_request(rpc_method: "tools/list"), headers:)
      expect(response.headers["Mcp-Session-Id"]).to eq("stateless")
    end

    describe "tools/list" do
      it "lists available tools" do
        post("/mcp", params: json_rpc_request(rpc_method: "tools/list"), headers:)
        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json["result"]["tools"]).to be_an(Array)

        tool_names = json["result"]["tools"].map { |t| t["name"] }
        expect(tool_names).to include("search", "get_show", "list_shows", "stats")
      end
    end

    describe "tools/call" do
      context "with search tool" do
        before { create(:song, title: "Tweezer") }

        it "executes search and returns results" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "search", arguments: { query: "Tweezer" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          expect(content).to be_an(Array)

          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])
          expect(result["songs"]).to be_an(Array)
        end

        it "returns error for query that is too short" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "search", arguments: { query: "T" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Query must be at least 2 characters")
        end

        it "returns error for query that is too long" do
          long_query = "a" * 201
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "search", arguments: { query: long_query } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Query must be 200 characters or fewer")
        end
      end

      context "with get_show tool" do
        let(:venue) { create(:venue) }
        let(:show) { create(:show, date: "2023-07-04", venue:) }

        before { create(:track, show:, position: 1, set: "1") }

        it "returns show details" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_show", arguments: { date: show.date.to_s } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["date"]).to eq("2023-07-04")
          expect(result["venue"]).to be_a(Hash)
          expect(result["tracks"]).to be_an(Array)
        end

        it "returns structured_content for widget" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_show", arguments: { date: show.date.to_s } }
          ), headers:)

          json = response.parsed_body
          structured_content = json.dig("result", "structuredContent")
          expect(structured_content["date"]).to eq("2023-07-04")
          expect(structured_content["tracks"]).to be_an(Array)
        end

        it "returns error for non-existent show" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_show", arguments: { date: "1900-01-01" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Show not found")
        end
      end

      context "with list_years tool" do
        let(:venue) { create(:venue) }

        before { create(:show, date: "1997-12-31", venue:) }

        it "returns years data" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_years", arguments: {} }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["years"]).to be_an(Array)
          expect(result["total_shows"]).to be_a(Integer)
        end
      end

      context "with stats tool" do
        let(:venue) { create(:venue, state: "NY", country: "USA") }
        let(:tour) { create(:tour, starts_on: "2023-07-01", ends_on: "2023-08-31") }
        let(:show) { create(:show, date: "2023-07-04", venue:, tour:, performance_gap_value: 1) }
        let(:song) { create(:song, title: "Tweezer") }

        before { create(:track, show:, position: 1, set: "1", songs: [ song ]) }

        it "executes gaps analysis" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "stats", arguments: { stat_type: "gaps", min_gap: 0, min_plays: 1 } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result).to have_key("songs")
          expect(result).to have_key("latest_show_date")
        end

        it "returns error for unknown stat_type" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "stats", arguments: { stat_type: "unknown_type" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          expect(json["error"]).to be_present
          expect(json["error"]["message"]).to include("error")
        end
      end
    end

    context "with invalid requests" do
      it "handles malformed JSON gracefully" do
        post("/mcp", params: "not valid json", headers:)
        expect(response).to have_http_status(:ok)
      end

      it "handles unknown method" do
        post("/mcp", params: json_rpc_request(rpc_method: "unknown/method"), headers:)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
