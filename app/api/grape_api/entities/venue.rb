class GrapeApi::Entities::Venue < GrapeApi::Entities::Base
  expose :slug
  expose :name
  expose :other_names
  expose :latitude
  expose :longitude
  expose :city
  expose :state
  expose :country
  expose :location
  expose :shows_count
  expose :updated_at, format_with: :iso8601
end
