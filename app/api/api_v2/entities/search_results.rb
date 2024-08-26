class ApiV2::Entities::SearchResults < ApiV2::Entities::Base
  expose \
    :exact_show,
    using: ApiV2::Entities::Show,
    documentation: {
      type: "Object",
      desc: "The show that exactly matches the search term"
    }

  expose \
    :other_shows,
    using: ApiV2::Entities::Show,
    default: [],
    documentation: {
      type: "Array",
      desc: "Other shows that vaguely match the search term"
    }

  expose \
    :songs,
    using: ApiV2::Entities::Song,
    default: [],
    documentation: {
      type: "Array",
      desc: "Songs that match the search term"
    }

  expose \
    :venues,
    using: ApiV2::Entities::Venue,
    default: [],
    documentation: {
      type: "Array",
      desc: "Venues that match the search term"
    }

  expose \
    :tours,
    using: ApiV2::Entities::Tour,
    default: [],
    documentation: {
      type: "Array",
      desc: "Tours that match the search term"
    }

  expose \
    :show_tags,
    using: ApiV2::Entities::ShowTag,
    default: [],
    documentation: {
      type: "Array",
      desc: "Show tags that match the search term"
    }

  expose \
    :track_tags,
    using: ApiV2::Entities::TrackTag,
    default: [],
    documentation: {
      type: "Array",
      desc: "Track tags that match the search term"
    }

  expose \
    :tracks,
    using: ApiV2::Entities::Track,
    default: [],
    documentation: {
      type: "Array",
      desc: "Tracks that match the search term"
    }

  expose \
    :tags,
    using: ApiV2::Entities::Tag,
    default: [],
    documentation: {
      type: "Array",
      desc: "Tags that match the search term"
    }
end
