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
      desc: "Duration of the track in milliseconds"
    }

  expose \
    :jam_starts_at_second,
    documentation: {
      type: "Integer",
      desc: "Second at which the jam section starts in the track"
    }

  expose \
    :set_name,
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
    :updated_at,
    format_with: :iso8601,
    documentation: {
      type: "String",
      desc: "Timestamp of the last update to the track"
    }

  expose \
    :show,
    using: ApiV2::Entities::Show,
    unless: ->(_obj, opts) { opts[:exclude_show] },
    documentation: {
      type: "Object",
      desc: "Show this track belongs to"
    }

  expose \
    :songs,
    using: ApiV2::Entities::Song,
    documentation: {
      is_array: true,
      desc: "Songs associated with the track"
  }

  expose :liked_by_user do |obj, opts|
    if opts.key?(:liked_by_user)
      opts[:liked_by_user]
    else
      opts[:liked_track_ids]&.include?(obj.id) || false
    end
  end
end
