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

      it "returns widget-free descriptions on default endpoint" do
        post("/mcp", params: json_rpc_request(rpc_method: "tools/list"), headers:)

        tools = response.parsed_body.dig("result", "tools")
        get_show = tools.find { |t| t["name"] == "get_show" }

        expect(get_show["description"]).not_to include("widget")
      end

      it "returns widget descriptions on openai endpoint" do
        post("/mcp/openai", params: json_rpc_request(rpc_method: "tools/list"), headers:)

        tools = response.parsed_body.dig("result", "tools")
        get_show = tools.find { |t| t["name"] == "get_show" }

        expect(get_show["description"]).to include("widget")
        expect(get_show["_meta"]).to include("openai/outputTemplate")
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

        it "returns structured_content for widget on openai endpoint" do
          post("/mcp/openai", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_show", arguments: { date: show.date.to_s } }
          ), headers:)

          json = response.parsed_body
          structured_content = json.dig("result", "structuredContent")
          expect(structured_content["date"]).to eq("2023-07-04")
          expect(structured_content["tracks"]).to be_an(Array)
        end

        it "does not return structured_content on default endpoint" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_show", arguments: { date: show.date.to_s } }
          ), headers:)

          json = response.parsed_body
          structured_content = json.dig("result", "structuredContent")
          expect(structured_content).to be_nil
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

      context "with get_audio_track tool" do
        let(:venue) { create(:venue) }
        let(:show) { create(:show, date: "1997-11-22", venue:) }
        let(:song) { create(:song, title: "Tweezer") }
        let!(:track) { create(:track, show:, position: 1, set: "1", songs: [ song ], slug: "tweezer") }

        it "returns track details by slug" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_audio_track", arguments: { slug: "1997-11-22/tweezer" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["title"]).to eq(track.title)
          expect(result["date"]).to eq("1997-11-22")
          expect(result["venue"]).to be_a(Hash)
        end

        it "returns random track when random is true" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_audio_track", arguments: { random: true } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["title"]).to be_present
        end

        it "returns error for non-existent track" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_audio_track", arguments: { slug: "2099-01-01/nonexistent" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Track not found")
        end
      end

      context "with get_playlist tool" do
        let(:user) { create(:user) }

        before { create(:playlist, name: "Best Jams", slug: "best-jams", user:) }

        it "returns playlist details by slug" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_playlist", arguments: { slug: "best-jams" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["name"]).to eq("Best Jams")
          expect(result["tracks"]).to be_an(Array)
        end

        it "returns random playlist when no slug provided" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_playlist", arguments: {} }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["name"]).to be_present
        end

        it "returns error for non-existent playlist" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_playlist", arguments: { slug: "nonexistent" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Playlist not found")
        end
      end

      context "with get_song tool" do
        let(:venue) { create(:venue) }
        let(:show) { create(:show, date: "1997-11-22", venue:) }
        let(:song) { create(:song, title: "Tweezer", slug: "tweezer") }

        before { create(:track, show:, position: 1, set: "1", songs: [ song ]) }

        it "returns song details by slug" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_song", arguments: { slug: "tweezer" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["title"]).to eq("Tweezer")
          expect(result["performances"]).to be_an(Array)
        end

        it "returns error for non-existent song" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_song", arguments: { slug: "nonexistent" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Song not found")
        end
      end

      context "with get_tag tool" do
        let(:venue) { create(:venue) }
        let(:show) { create(:show, date: "1997-11-22", venue:) }
        let(:tag) { create(:tag, name: "Jamcharts", slug: "jamcharts") }
        let!(:track) { create(:track, show:, position: 1, set: "1") }

        before { create(:track_tag, track:, tag:) }

        it "returns tagged tracks" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_tag", arguments: { slug: "jamcharts", type: "track" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["name"]).to eq("Jamcharts")
          expect(result["tracks"]).to be_an(Array)
        end

        it "returns tagged shows" do
          create(:show_tag, show:, tag:)

          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_tag", arguments: { slug: "jamcharts", type: "show" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["name"]).to eq("Jamcharts")
          expect(result["shows"]).to be_an(Array)
        end

        it "returns error for non-existent tag" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_tag", arguments: { slug: "nonexistent", type: "track" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Tag not found")
        end
      end

      context "with get_tour tool" do
        before { create(:tour, name: "Fall Tour 1997", slug: "fall-tour-1997", starts_on: "1997-11-01", ends_on: "1997-12-31") }

        it "returns tour details by slug" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_tour", arguments: { slug: "fall-tour-1997" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["name"]).to eq("Fall Tour 1997")
          expect(result["starts_on"]).to eq("1997-11-01")
        end

        it "returns random tour when random is true" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_tour", arguments: { random: true } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["name"]).to be_present
        end

        it "returns error for non-existent tour" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_tour", arguments: { slug: "nonexistent" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Tour not found")
        end
      end

      context "with get_venue tool" do
        let(:venue) { create(:venue, name: "Madison Square Garden", slug: "madison-square-garden", city: "New York", state: "NY", shows_count: 1) }

        before { create(:show, venue:) }

        it "returns venue details by slug" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_venue", arguments: { slug: "madison-square-garden" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["name"]).to eq("Madison Square Garden")
          expect(result["city"]).to eq("New York")
        end

        it "returns random venue when random is true" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_venue", arguments: { random: true } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["name"]).to be_present
        end

        it "returns error for non-existent venue" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "get_venue", arguments: { slug: "nonexistent" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("Venue not found")
        end
      end

      context "with list_playlists tool" do
        let(:user) { create(:user) }

        before { create_list(:playlist, 3, user:) }

        it "returns playlists list" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_playlists", arguments: {} }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["playlists"]).to be_an(Array)
          expect(result["total"]).to eq(3)
        end

        it "respects limit parameter" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_playlists", arguments: { limit: 2 } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["playlists"].size).to eq(2)
        end
      end

      context "with list_shows tool" do
        let(:venue) { create(:venue) }
        let(:tour) { create(:tour, slug: "fall-tour-1997", starts_on: "1997-11-01", ends_on: "1997-12-31") }

        before do
          create(:show, date: "1997-11-22", venue:, tour:)
          create(:show, date: "1997-11-23", venue:, tour:)
        end

        it "returns shows filtered by year" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_shows", arguments: { year: 1997 } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["shows"]).to be_an(Array)
          expect(result["total"]).to eq(2)
        end

        it "returns shows filtered by tour slug" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_shows", arguments: { tour_slug: "fall-tour-1997" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["shows"]).to be_an(Array)
        end

        it "returns error when no filter provided" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_shows", arguments: {} }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          expect(text_content["text"]).to include("At least one filter required")
        end
      end

      context "with list_songs tool" do
        before do
          create(:song, title: "Tweezer", original: true, tracks_count: 10)
          create(:song, title: "Also Sprach Zarathustra", original: false, tracks_count: 5)
        end

        it "returns songs list" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_songs", arguments: {} }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["songs"]).to be_an(Array)
          expect(result["total"]).to eq(2)
        end

        it "filters by original songs" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_songs", arguments: { song_type: "original" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["songs"].size).to eq(1)
          expect(result["songs"].first["title"]).to eq("Tweezer")
        end

        it "filters by cover songs" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_songs", arguments: { song_type: "cover" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["songs"].size).to eq(1)
          expect(result["songs"].first["title"]).to eq("Also Sprach Zarathustra")
        end
      end

      context "with list_tags tool" do
        before do
          create(:tag, name: "Jamcharts", slug: "jamcharts")
          create(:tag, name: "Guest", slug: "guest")
        end

        it "returns tags list" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_tags", arguments: {} }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["tags"]).to be_an(Array)
          expect(result["total"]).to eq(2)
        end
      end

      context "with list_tours tool" do
        before do
          create(:tour, name: "Fall Tour 1997", starts_on: "1997-11-01", ends_on: "1997-12-31")
          create(:tour, name: "Summer Tour 1998", starts_on: "1998-06-01", ends_on: "1998-08-31")
        end

        it "returns tours list" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_tours", arguments: {} }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["tours"]).to be_an(Array)
          expect(result["total"]).to eq(2)
        end

        it "filters by year" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_tours", arguments: { year: 1997 } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["tours"].size).to eq(1)
          expect(result["tours"].first["name"]).to eq("Fall Tour 1997")
        end
      end

      context "with list_venues tool" do
        before do
          create(:venue, name: "Madison Square Garden", city: "New York", state: "NY", country: "USA")
          create(:venue, name: "The Fillmore", city: "San Francisco", state: "CA", country: "USA")
        end

        it "returns venues list" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_venues", arguments: {} }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["venues"]).to be_an(Array)
          expect(result["total"]).to eq(2)
        end

        it "filters by state" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_venues", arguments: { state: "NY" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["venues"].size).to eq(1)
          expect(result["venues"].first["name"]).to eq("Madison Square Garden")
        end

        it "filters by city" do
          post("/mcp", params: json_rpc_request(
            rpc_method: "tools/call",
            params: { name: "list_venues", arguments: { city: "San Francisco" } }
          ), headers:)

          expect(response).to have_http_status(:ok)

          json = response.parsed_body
          content = json.dig("result", "content")
          text_content = content.find { |c| c["type"] == "text" }
          result = JSON.parse(text_content["text"])

          expect(result["venues"].size).to eq(1)
          expect(result["venues"].first["name"]).to eq("The Fillmore")
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
