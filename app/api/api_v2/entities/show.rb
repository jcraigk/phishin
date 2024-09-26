class ApiV2::Entities::Show < ApiV2::Entities::Base
  expose \
    :id,
    documentation: {
      type: "Integer",
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

  expose \
    :admin_notes,
    documentation: {
      type: "String",
      desc: "Administrator's notes related to the show"
    }

  expose(
    :tour_name,
    documentation: {
      type: "String",
      desc: "Name of the tour the show belongs to"
    }
  ) { _1.tour.name }

  expose \
    :venue_name,
    documentation: {
      type: "String",
      desc: \
        "Name of the venue where the show took place, reflecting " \
        "the name at the time (not necessarily the current name)"
    }

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
    if: ->(_, opts) { opts[:include_tracks] },
    documentation: {
      is_array: true,
      desc: "Tracks associated with the show, included only on individual show requests"
    }
  ) do
    ApiV2::Entities::Track.represent \
      _1.tracks.sort_by(&:position),
      _2.merge(exclude_show: true, liked_by_user: nil)
  end

  expose(
    :liked_by_user
  ) do
    unless _2[:liked_by_user].nil?
      _2[:liked_by_user]
    else
      _2[:liked_show_ids]&.include?(_1.id) || false
    end
  end

  expose(
    :previous_show_date,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "Date of the previous show (or last show if none exists)"
    }
  ) { _2[:previous_show_date] }

  expose(
    :next_show_date,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "Date of the next show (or first show if none exists)"
    }
  ) { _2[:next_show_date] }
end
