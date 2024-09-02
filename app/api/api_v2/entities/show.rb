class ApiV2::Entities::Show < ApiV2::Entities::Base
  expose \
    :id,
    documentation: {
      type: "String",
      desc: "ID of the show"
    }

  expose \
    :date,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "Date of the show"
    }

  expose \
    :duration,
    documentation: {
      type: "Integer",
      desc: "Duration of the show in milliseconds"
    }

  expose \
    :incomplete,
    documentation: {
      type: "Boolean",
      desc: "Indicates if the audio recording of the show is incomplete"
    }

  expose(
    :tour_name,
    documentation: {
      type: "String",
      desc: "Name of the tour the show belongs to"
    }
  ) { _1.tour.name }

  expose \
    :venue,
    using: ApiV2::Entities::Venue,
    documentation: {
      type: "Object",
      desc: "Venue where the show took place"
    }

  expose \
    :taper_notes,
    documentation: {
      type: "String",
      desc: "Notes from the taper of the show"
    }

  expose \
    :likes_count,
    documentation: {
      type: "Integer",
      desc: "Number of likes the show has received"
    }

  expose \
    :updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of the last update"
    }

  expose \
    :show_tags,
    using: ApiV2::Entities::ShowTag,
    as: :tags,
    documentation: {
      is_array: true,
      desc: "Tags associated with the show"
    }

  expose(
    :tracks,
    # using: ApiV2::Entities::Track, # TODO: Fixes docs, breaks the data
    if: ->(_obj, opts) { opts[:include_tracks] },
    documentation: {
      is_array: true,
      desc: "Tracks associated with the show, included only on individual show requests"
    }
  ) do |obj, opts|
    ApiV2::Entities::Track.represent \
      obj.tracks.sort_by(&:position),
      opts.merge(exclude_show: true)
  end
end
