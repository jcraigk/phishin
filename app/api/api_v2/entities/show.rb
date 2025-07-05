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
    :audio_status,
    documentation: {
      type: "String",
      desc: "Audio status of the show: 'complete', 'partial', or 'missing'"
    }

  expose(
    :cover_art_urls,
    documentation: {
      type: "Object",
      desc: "Object containing named URLs for variants of raw cover art images"
    }
  )

  expose(
    :album_cover_url,
    documentation: {
      type: "String",
      desc: "URL of album cover image (text overlayed on cover art)"
    }
  )

  expose(
    :album_zip_url,
    documentation: {
      type: "String",
      desc: "URL of zipfile containing the show's MP3s, cover art, and taper notes"
    }
  )

  expose \
    :duration,
    documentation: {
      type: "Integer",
      desc: "Duration of the show in milliseconds"
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
  ) { it.tour.name }

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
    :performance_gap_value,
    documentation: {
      type: "Integer",
      desc: "The value to use when calculating song performance gaps (default 1). Some records in the database represent multiple shows that took place on the same date (>1) while others were performances that don't count toward gaps and personal stats (0)."
    }

  expose \
    :created_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of initial creation"
    }

  expose \
    :updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of most recent update"
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
    unless: ->(_, opts) { opts[:exclude_tracks] },
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
      desc: "Date of the previous show (including missing audio)"
    }
  ) { _2[:previous_show_date] }

  expose(
    :next_show_date,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "Date of the next show (including missing audio)"
    }
  ) { _2[:next_show_date] }

  expose(
    :previous_show_date_with_audio,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "Date of the previous show with audio (or last show with audio if none exists)"
    }
  ) { _2[:previous_show_date_with_audio] }

  expose(
    :next_show_date_with_audio,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "Date of the next show with audio (or first show with audio if none exists)"
    }
  ) { _2[:next_show_date_with_audio] }
end
