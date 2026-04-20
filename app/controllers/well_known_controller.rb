class WellKnownController < ActionController::Base
  HTTP_CACHE_TTL = 1.hour

  def mcp_server_card
    cache_json(
      schema_version: "2025-06-18",
      name: "phishin",
      title: App.app_name,
      description: App.app_desc,
      version: "1.0.0",
      vendor: { name: App.app_name, url: App.base_url },
      homepage: App.base_url,
      documentation: "#{App.base_url}/llms.txt",
      icons: [
        { src: "#{App.base_url}/logo.svg", mime_type: "image/svg+xml", purpose: "logo" },
        { src: "#{App.base_url}/favicon.ico", mime_type: "image/x-icon", purpose: "favicon" }
      ],
      servers: Server::VALID_CLIENTS.map { |client|
        endpoint = client == :default ? "#{App.base_url}/mcp" : "#{App.base_url}/mcp/#{client}"
        {
          name: client.to_s,
          description: client_description(client),
          transport: "streamable-http",
          url: endpoint,
          protocol_version: "2025-03-26",
          authentication: { type: "none" }
        }
      },
      capabilities: { tools: true, resources: Server::WIDGET_CLIENTS.any?, prompts: false }
    )
  end

  def api_catalog
    response.headers["Content-Type"] = "application/linkset+json"
    cache_json(
      linkset: [
        {
          anchor: App.base_url,
          "service-desc": [
            {
              href: "#{App.base_url}/api/v2/swagger_doc",
              type: "application/openapi+json",
              title: "Phish.in API v2 (OpenAPI)"
            }
          ],
          "service-doc": [
            { href: "#{App.base_url}/api-docs", type: "text/html", title: "API docs" },
            { href: "#{App.base_url}/llms.txt", type: "text/plain", title: "Agent-readable site summary" }
          ],
          related: [
            { href: "#{App.base_url}/mcp", type: "application/json", title: "MCP endpoint" },
            { href: "#{App.base_url}/.well-known/mcp/server-card.json", type: "application/json", title: "MCP Server Card" }
          ]
        }
      ]
    )
  end

  def a2a_agent_card
    cache_json(
      schema_version: "0.3.0",
      name: "phishin",
      description: "Agent interface for the Phish.in live Phish audio archive. " \
                   "Browse and play shows, songs, venues, tours, tags, and playlists.",
      url: "#{App.base_url}/mcp",
      provider: { organization: App.app_name, url: App.base_url },
      version: "1.0.0",
      documentation_url: "#{App.base_url}/llms.txt",
      icon_url: "#{App.base_url}/logo.svg",
      capabilities: { streaming: false, push_notifications: false, state_transition_history: false },
      default_input_modes: %w[text/plain application/json],
      default_output_modes: %w[text/plain application/json],
      skills: skill_summaries.map { |s|
        {
          id: s[:id],
          name: s[:id].to_s,
          description: s[:description],
          tags: s[:tags],
          examples: s[:examples]
        }
      }
    )
  end

  def agent_skills_index
    cache_json(
      schema_version: "0.2.0",
      name: "phishin",
      description: App.app_desc,
      skills: skill_summaries.map { |s|
        {
          id: s[:id],
          name: s[:id].to_s,
          description: s[:description],
          input_schema: s[:input_schema],
          tags: s[:tags],
          examples: s[:examples],
          invocation: {
            transport: "mcp",
            endpoint: "#{App.base_url}/mcp",
            tool: s[:id].to_s
          }
        }
      }
    )
  end

  private

  def cache_json(payload)
    expires_in HTTP_CACHE_TTL, public: true
    render json: payload
  end

  def client_description(client)
    case client
    when :openai then "ChatGPT connector endpoint with interactive widgets"
    when :anthropic then "Claude connector endpoint with interactive widgets"
    else "Default streamable-HTTP MCP endpoint"
    end
  end

  def skill_summaries
    @skill_summaries ||= ToolBuilder.base_tools.map { |klass|
      id = klass.name_value.to_sym
      {
        id:,
        description: Descriptions::BASE[id],
        input_schema: klass.try(:input_schema_value)&.to_h,
        tags: %w[phish live-music archive],
        examples: skill_examples[id] || []
      }
    }
  end

  def skill_examples
    {
      search: [ "Find all shows at Madison Square Garden", "Search for Tweezer jams" ],
      get_show: [ "Get the Halloween 1995 show", "Random Phish show" ],
      get_song: [ "Show me the history of Tweezer" ],
      get_audio_track: [ "Play a random Phish track", "Play Tweezer from 1997-11-22" ],
      list_shows: [ "List all 1995 shows", "Shows at Red Rocks" ],
      list_songs: [ "All Phish songs starting with T" ],
      list_venues: [ "Venues in Colorado" ],
      stats: [ "Longest gap for Harpua", "Most-played songs of 1997" ]
    }
  end
end
