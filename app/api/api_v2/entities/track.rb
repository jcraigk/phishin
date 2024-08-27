class ApiV2::Entities::Track < ApiV2::Entities::Base
  expose \
    :id,
    documentation: {
      type: "String",
      desc: "ID of the track"
    }

  expose \
    :slug,
    documentation: {
      type: "String",
      desc: "Unique slug identifier for the track"
    }

  expose \
    :show_id,
    documentation: {
      type: "Integer",
      desc: "ID of the show this track belongs to"
    }

  with_options if: ->(_obj, opts) { opts[:show_details] } do
    expose \
      :show_date,
      documentation: {
        type: "String",
        format: "date",
        desc:
          "Date of the show this track belongs to, " \
          "included only if not part of a show request"
      } do |track|
        track.show.date.iso8601
    end

    expose \
      :venue_name,
      documentation: {
        type: "String",
        desc:
          "Name of the venue where the show took place, " \
          "included only if not part of a show request"
      } do |track|
        track.show.venue.name
    end

    expose \
      :venue_location,
      documentation: {
        type: "String",
        desc:
          "Location (city, state, country) of the venue, " \
          "included only if not part of a show request"
      } do |track|
        track.show.venue.location
    end
  end

  expose \
    :title,
    documentation: {
      type: "String",
      desc: "Title of the track"
    }

  expose \
    :position,
    documentation: {
      type: "Integer",
      desc: "Position of the track in the setlist"
    }

  expose \
    :duration,
    documentation: {
      type: "Integer",
      desc: "Duration of the track in seconds"
    }

  expose \
    :jam_starts_at_second,
    documentation: {
      type: "Integer",
      desc: "Second at which the jam section starts in the track"
    }

  expose \
    :set,
    documentation: {
      type: "Integer",
      desc: "Set number this track belongs to"
    }

  expose \
    :likes_count,
    documentation: {
      type: "Integer",
      desc: "Number of likes the track has received"
    }

  expose \
    :mp3_url,
    documentation: {
      type: "String",
      desc: "URL to the MP3 file of the track"
    } do |track|
      track.mp3_url
  end

  expose \
    :waveform_image_url,
    documentation: {
      type: "String",
      desc: "URL to the waveform image of the track"
    } do |track|
      track.waveform_image_url
  end

  expose \
    :track_tags,
    using: ApiV2::Entities::TrackTag,
    as: :tags,
    documentation: {
      is_array: true,
      desc: "Tags associated with the track"
    }

  expose \
    :songs,
    using: ApiV2::Entities::Song,
    documentation: {
      is_array: true,
      desc: "Songs associated with the track"
  }

  expose \
    :updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date-time",
      desc: "Timestamp of the last update to the track"
    }
end
