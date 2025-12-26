class Server
  def self.instance
    @instance ||= MCP::Server.new(
      name: "phishin",
      version: "1.0.0",
      tools: [
        Tools::GetPlaylist,
        Tools::GetSong,
        Tools::GetTour,
        Tools::GetVenue,
        Tools::ListShows,
        Tools::ListSongs,
        Tools::ListTours,
        Tools::ListVenues,
        Tools::ListYears,
        Tools::Search,
        Tools::Stats
      ],
      configuration: MCP::Configuration.new(protocol_version: "2024-11-05")
    )
  end
end
