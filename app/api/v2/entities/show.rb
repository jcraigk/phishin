module Api::V2::Entities
  class Show < Grape::Entity
    expose :date, format_with: :iso8601
    expose :duration
    expose :incomplete
    # expose :tags, using: API::V2::Entities::TagEntity, if: ->(show, _) { show.tags.any? }
    # expose :tour_name
    # expose :latitude
    # expose :longitude
    expose :venue_id
    expose :venue_name
    expose :taper_notes
    expose :likes_count
    expose :updated_at, format_with: :iso8601
    # expose :tracks, using: API::V2::Entities::TrackEntity


    private

    format_with :iso8601 do |date|
      date.iso8601
    end
  end
end
