class GrapeApi::Entities::Tour < GrapeApi::Entities::Base
  expose :slug
  expose :name
  expose :shows_count
  expose :starts_on, format_with: :iso8601
  expose :ends_on, format_with: :iso8601
  expose :updated_at, format_with: :iso8601
  expose :shows,
         using: GrapeApi::Entities::Show,
         if: ->(_, opts) { opts[:include_shows] }
end
