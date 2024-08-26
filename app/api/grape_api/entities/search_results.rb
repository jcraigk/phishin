class GrapeApi::Entities::SearchResults < GrapeApi::Entities::Base
  expose :exact_show, using: GrapeApi::Entities::Show
  expose :other_shows, using: GrapeApi::Entities::Show, default: []
  expose :songs, using: GrapeApi::Entities::Song, default: []
  expose :venues, using: GrapeApi::Entities::Venue, default: []
  expose :tours, using: GrapeApi::Entities::Tour, default: []
  expose :show_tags, using: GrapeApi::Entities::ShowTag, default: []
  expose :track_tags, using: GrapeApi::Entities::TrackTag, default: []
  expose :tracks, using: GrapeApi::Entities::Track, default: []
  expose :tags, using: GrapeApi::Entities::Tag, default: []
end
