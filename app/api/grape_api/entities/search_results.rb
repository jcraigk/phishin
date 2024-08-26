class GrapeApi::Entities::SearchResults < GrapeApi::Entities::Base
  expose \
    :exact_show,
    using: GrapeApi::Entities::Show,
    documentation: {
      type: "Object",
      desc: "The show that exactly matches the search term"
    }

  expose \
    :other_shows,
    using: GrapeApi::Entities::Show,
    default: [],
    documentation: {
      type: "Array",
      desc: "Other shows that vaguely match the search term"
    }

  expose \
    :songs,
    using: GrapeApi::Entities::Song,
    default: [],
    documentation: {
      type: "Array",
      desc: "Songs that match the search term"
    }

  expose \
    :venues,
    using: GrapeApi::Entities::Venue,
    default: [],
    documentation: {
      type: "Array",
      desc: "Venues that match the search term"
    }

  expose \
    :tours,
    using: GrapeApi::Entities::Tour,
    default: [],
    documentation: {
      type: "Array",
      desc: "Tours that match the search term"
    }

  expose \
    :show_tags,
    using: GrapeApi::Entities::ShowTag,
    default: [],
    documentation: {
      type: "Array",
      desc: "Show tags that match the search term"
    }

  expose \
    :track_tags,
    using: GrapeApi::Entities::TrackTag,
    default: [],
    documentation: {
      type: "Array",
      desc: "Track tags that match the search term"
    }

  expose \
    :tracks,
    using: GrapeApi::Entities::Track,
    default: [],
    documentation: {
      type: "Array",
      desc: "Tracks that match the search term"
    }

  expose \
    :tags,
    using: GrapeApi::Entities::Tag,
    default: [],
    documentation: {
      type: "Array",
      desc: "Tags that match the search term"
    }
end
