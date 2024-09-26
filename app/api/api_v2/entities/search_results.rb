class ApiV2::Entities::SearchResults < ApiV2::Entities::Base
  expose(
    :exact_show,
    using: ApiV2::Entities::Show,
    documentation: {
      type: "Object",
      desc: \
        "The show that exactly matches the specified date (if any). " \
        "Returns a show object including venue and date information. " \
        "Null if no exact match is found."
    }
  )

  expose(
    :other_shows,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "Shows that occurred on the same day of the year as the search date, " \
        "from any year. Returns an array of show objects including date " \
        "and venue details. Empty array if no shows are found."
    }
  ) do
    ApiV2::Entities::Show.represent \
      _1[:other_shows],
      _2.merge(liked_by_user: nil)
  end

  expose \
    :songs,
    using: ApiV2::Entities::Song,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "An array of songs that match the search term in title or alias. " \
        "Each song object includes title and artist details. " \
        "Empty if no songs match."
    }

  expose \
    :venues,
    using: ApiV2::Entities::Venue,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "An array of venues where the name, abbreviation, city, state, or " \
        "country matches the search term. Each venue object contains " \
        "detailed venue information. Returns an empty array if no venues match."
    }

  expose \
    :show_tags,
    using: ApiV2::Entities::ShowTag,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "Tags applied to shows that match the search term in their notes. " \
        "Each show tag object includes the tag name and associated show details. " \
        "Returns an empty array if no tags match."
    }

  expose \
    :track_tags,
    using: ApiV2::Entities::TrackTag,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "Tags applied to tracks that match the search term in their notes. " \
        "Each track tag object includes the tag name and the associated " \
        "track and show details. Empty array if no track tags match."
    }

  expose(
    :tracks,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "Tracks that match the search term in title. Does not include tracks " \
        "where the title matches a song title to avoid duplicates. " \
        "Each track object includes show and track details. Empty array " \
        "if no tracks match."
    }
  ) do
    ApiV2::Entities::Track.represent \
      _1[:tracks],
      _2.merge(exclude_show: true, liked_by_user: nil)
  end

  expose \
    :tags,
    using: ApiV2::Entities::Tag,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "Tags that match the search term either in name or description. " \
        "Each tag object includes the tag name and details. Returns an empty " \
        "array if no tags match."
    }

    expose(
      :playlists,
      default: [],
      documentation: {
        type: "Array[Object]",
        desc: \
          "An array of playlists whose name matches the search term. " \
          "Does not include track information."
      }
    ) do
      ApiV2::Entities::Playlist.represent \
        _1[:playlists],
        _2.merge(liked_by_user: nil, exclude_tracks: true)
    end
end
