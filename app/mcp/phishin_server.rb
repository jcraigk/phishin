require_relative "tools/get_playlist"
require_relative "tools/get_show"
require_relative "tools/get_song"
require_relative "tools/get_tour"
require_relative "tools/get_venue"
require_relative "tools/search"
require_relative "tools/stats"

class PhishinServer
  def self.build
    MCP::Server.new(
      name: "phishin",
      version: "1.0.0",
      tools: [
        Mcp::Tools::GetPlaylist,
        Mcp::Tools::GetShow,
        Mcp::Tools::GetSong,
        Mcp::Tools::GetTour,
        Mcp::Tools::GetVenue,
        Mcp::Tools::Search,
        Mcp::Tools::Stats
      ]
    )
  end
end





