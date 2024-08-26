class GrapeApi::Entities::Playlist < GrapeApi::Entities::Base
  expose :slug
  expose :name
  expose(:username) { _1.user.username }
  expose :duration
  expose :tracks, using: GrapeApi::Entities::Track
  expose :updated_at, format_with: :iso8601
end
