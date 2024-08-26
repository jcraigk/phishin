class GrapeApi::Entities::Song < GrapeApi::Entities::Base
  expose :slug
  expose :title
  expose :alias
  expose :original
  expose :artist
  expose :tracks_count
  expose :updated_at, format_with: :iso8601
end
