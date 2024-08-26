class GrapeApi::Entities::Show < GrapeApi::Entities::Base
  expose :date,
         format_with: :iso8601,
         documentation: {
           type: "String",
           format: "date",
           desc: "Date of the show in ISO8601 format"
         }

  expose :duration,
         documentation: {
           type: "Integer",
           desc: "Duration of the show in seconds"
         }

  expose :incomplete,
         documentation: {
           type: "Boolean",
           desc: "Indicates if the show is incomplete"
         }

  expose(
    :tour_name,
    documentation: {
      type: "String",
      desc: "Name of the tour the show belongs to"
    }
  ) { _1.tour.name }

  expose :venue_name,
         documentation: {
           type: "String",
           desc: "Name of the venue where the show took place"
         }

  expose(
    :venue_latitude,
    documentation: {
      type: "Float",
      desc: "Latitude of the venue"
    }
  ) { _1.venue.latitude }

  expose(
    :venue_longitude,
    documentation: {
      type: "Float",
      desc: "Longitude of the venue"
    }
  ) { _1.venue.longitude }

  expose(
    :venue_location,
    documentation: {
      type: "String",
      desc: "Location (city, state, country) of the venue"
    }
  ) { _1.venue.location }

  expose(
    :venue_slug,
    documentation: {
      type: "String",
      desc: "Slug of the venue"
    }
  ) { _1.venue.slug }

  expose :taper_notes,
         documentation: {
           type: "String",
           desc: "Notes from the taper of the show"
         }

  expose :likes_count,
         documentation: {
           type: "Integer",
           desc: "Number of likes the show has received"
         }

  expose :updated_at,
         format_with: :iso8601,
         documentation: {
           type: "String",
           format: "date-time",
           desc: "Timestamp of the last update in ISO8601 format"
         }

  expose :show_tags,
         using: GrapeApi::Entities::ShowTag,
         as: :tags,
         documentation: {
           is_array: true,
           desc: "Tags associated with the show"
         }

  expose(
    :tracks,
    if: ->(_obj, opts) { opts[:include_tracks] },
    documentation: {
      is_array: true,
      desc: "Tracks associated with the show"
    }
  ) do
    GrapeApi::Entities::Track.represent(
      _1.tracks.sort_by(&:position),
      show_details: true
    )
  end
end
