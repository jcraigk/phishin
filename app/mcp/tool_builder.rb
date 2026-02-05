module ToolBuilder
  def self.build_tools(client:)
    base_tools.map { |base_class| build_tool(base_class, client:) }
  end

  def self.build_tool(base_class, client:)
    tool_name_str = base_class.name_value
    desc = Descriptions.for(tool_name_str, client)
    tool_meta = base_class.try(:"#{client}_meta")
    base_schema = base_class.try(:input_schema_value)
    base_annotations = base_class.try(:annotations_value)

    Class.new(base_class) do
      tool_name tool_name_str
      description desc
      input_schema(base_schema) if base_schema.present?

      if base_annotations.present?
        annotations(
          read_only_hint: base_annotations.read_only_hint,
          destructive_hint: base_annotations.destructive_hint,
          idempotent_hint: base_annotations.idempotent_hint,
          open_world_hint: base_annotations.open_world_hint,
          title: base_annotations.title
        )
      end

      meta(tool_meta) if tool_meta.present?

      define_singleton_method(:mcp_client) { client }
    end
  end

  def self.base_tools
    [
      Tools::GetAudioTrack,
      Tools::GetPlaylist,
      Tools::GetShow,
      Tools::GetSong,
      Tools::GetTag,
      Tools::GetTour,
      Tools::GetVenue,
      Tools::ListPlaylists,
      Tools::ListShows,
      Tools::ListSongs,
      Tools::ListTags,
      Tools::ListTours,
      Tools::ListVenues,
      Tools::ListYears,
      Tools::Search,
      Tools::Stats
    ]
  end
end
