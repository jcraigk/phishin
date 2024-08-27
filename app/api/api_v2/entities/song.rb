class ApiV2::Entities::Song < ApiV2::Entities::Base
  expose \
    :slug,
    documentation: {
      type: "String",
      desc: "Unique slug identifier for the song"
    }

  expose \
    :title,
    documentation: {
      type: "String",
      desc: "Title of the song"
    }

  expose \
    :alias,
    documentation: {
      type: "String",
      desc: "Alias or alternate title of the song, if any"
    }

  expose \
    :original,
    documentation: {
      type: "Boolean",
      desc: "Indicates if the song is an original composition"
    }

  expose \
    :artist,
    documentation: {
      type: "String",
      desc: "Artist associated with the song (if not original)"
    }

  expose \
    :tracks_count,
    documentation: {
      type: "Integer",
      desc: "Number of tracks associated with the song"
    }

  expose \
    :updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of the last update to the song"
    }
end
