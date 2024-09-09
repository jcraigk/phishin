class ApiV2::Entities::SearchResults < ApiV2::Entities::Base
  expose \
    :exact_show,
    using: ApiV2::Entities::Show,
    documentation: {
      type: "Object",
      desc: \
        "The show that exactly matches the specified date (if any). " \
        "Returns a show object including venue and date information. " \
        "Null if no exact match is found."
    }

  expose \
    :other_shows,
    using: ApiV2::Entities::Show,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "Shows that occurred on the same day of the year as the search date, " \
        "from any year. Returns an array of show objects including date " \
        "and venue details. Empty array if no shows are found."
    }

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
    :tours,
    using: ApiV2::Entities::Tour,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "Tours that match the search term by name. Each tour object contains " \
        "details such as tour name and start/end dates. Returns an empty " \
        "array if no tours match."
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

  expose \
    :tracks,
    using: ApiV2::Entities::Track,
    default: [],
    documentation: {
      type: "Array[Object]",
      desc: \
        "Tracks that match the search term in title. Does not include tracks " \
        "where the title matches a song title to avoid duplicates. " \
        "Each track object includes show and track details. Empty array " \
        "if no tracks match."
    }

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
end
