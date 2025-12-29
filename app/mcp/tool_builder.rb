module ToolBuilder
  def self.build_tools(client:)
    base_tools.map { |base_class| build_tool(base_class, client:) }
  end

  def self.build_tool(base_class, client:)
    tool_name_str = base_class.name_value
    desc = Descriptions.for(tool_name_str, client)
    tool_meta = client == :openai ? base_class.try(:openai_meta) : nil
    base_schema = base_class.try(:input_schema_value)

    Class.new(base_class) do
      tool_name tool_name_str
      description desc
      input_schema(base_schema) if base_schema.present?

      meta(tool_meta) if tool_meta.present?

      define_singleton_method(:mcp_client) { client }
    end
  end

  def self.base_tools
    [
      Tools::GetPlaylist,
      Tools::GetShow,
      Tools::GetSong,
      Tools::GetTour,
      Tools::GetVenue,
      Tools::ListPlaylists,
      Tools::ListShows,
      Tools::ListSongs,
      Tools::ListTours,
      Tools::ListVenues,
      Tools::ListYears,
      Tools::Search,
      Tools::Stats
    ]
  end
end
