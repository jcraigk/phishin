module GrapeApi::Entities
  class Show < Grape::Entity
    expose :date, format_with: :iso8601
    expose :duration
    expose :incomplete
    expose(:tour_name) { |obj, _opts| obj.tour.name }
    expose :venue_name
    expose(:venue_latitude) { |obj, _opts| obj.venue.latitude }
    expose(:venue_longitude) { |obj, _opts| obj.venue.longitude }
    expose(:venue_location) { |obj, _opts| obj.venue.location }
    expose(:venue_slug) { |obj, _opts| obj.venue.slug }
    expose :taper_notes
    expose :likes_count
    expose :updated_at, format_with: :iso8601
    expose :show_tags, using: GrapeApi::Entities::ShowTag, as: :tags
    expose(
      :tracks,
      if: ->(_obj, opts) { opts[:include_tracks] }
    ) do |obj, opts|
      GrapeApi::Entities::Track.represent \
        obj.tracks.sort_by(&:position),
        show_details: true
    end

    private

    format_with :iso8601 do |date|
      date.iso8601
    end
  end
end
