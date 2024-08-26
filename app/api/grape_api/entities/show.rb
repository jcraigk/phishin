class GrapeApi::Entities::Show < GrapeApi::Entities::Base
  expose :date, format_with: :iso8601
  expose :duration
  expose :incomplete
  expose(:tour_name) { _1.tour.name }
  expose :venue_name
  expose(:venue_latitude) { _1.venue.latitude }
  expose(:venue_longitude) { _1.venue.longitude }
  expose(:venue_location) { _1.venue.location }
  expose(:venue_slug) { _1.venue.slug }
  expose :taper_notes
  expose :likes_count
  expose :updated_at, format_with: :iso8601
  expose :show_tags, using: GrapeApi::Entities::ShowTag, as: :tags
  expose(
    :tracks,
    if: ->(_obj, opts) { opts[:include_tracks] }
  ) do
    GrapeApi::Entities::Track.represent \
      _1.tracks.sort_by(&:position),
      show_details: true
  end
end
