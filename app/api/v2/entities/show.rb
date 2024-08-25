module Api::V2::Entities
  class Show < Grape::Entity
    expose :id
    expose :date, format_with: :iso8601
    expose :duration
    expose :incomplete
    # expose :tags, using: API::V2::Entities::TagEntity, if: ->(show, _) { show.tags.any? }
    # expose :tour, using: API::V2::Entities::TourEntity
    # expose :venue, using: API::V2::Entities::VenueEntity
    expose :venue_name
    expose :taper_notes
    expose :likes_count
    # expose :tracks, using: API::V2::Entities::TrackEntity, if: ->(show, _) { show.tracks.any? }
    expose :updated_at, format_with: :iso8601

    private

    format_with :iso8601 do |date|
      date.iso8601
    end
  end
end
