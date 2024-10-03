class ApiV2::Entities::Track < ApiV2::Entities::Base
  expose \
    :id,
    documentation: {
      type: "Integer",
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
    }

  expose \
    :waveform_image_url,
    documentation: {
      type: "String",
      desc: "URL to the waveform image of the track"
    }

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

  expose(
    :show_date,
    format_with: :iso8601,
    documentation: {
      type: "String",
      format: "date",
      desc: "Date of the show that the track belongs to"
    }
  ) { _1.show.date }

  expose(
    :show_cover_art_urls,
    documentation: {
      type: "Object",
      desc: "Object containing named URLs for variants of raw cover art images"
    }
  ) do
    show = _1.show
    if show.cover_art.attached?
      {
        medium:
          Rails.application
               .routes
               .url_helpers
               .rails_blob_url(show.cover_art),
        small:
          Rails.application
               .routes
               .url_helpers
               .rails_representation_url(
                show.cover_art.variant(:small).processed
               )
      }
    else
      {
        medium:
          ActionController::Base.helpers.asset_pack_path(
            "static/images/placeholders/cover-art-original.jpg"
          ),
        small:
          ActionController::Base.helpers.asset_pack_path(
            "static/images/placeholders/cover-art-small.jpg"
          )
      }
    end
  end

  expose(
    :show_album_cover_url,
    documentation: {
      type: "Object",
      desc: "Object containing named URLs for variants of cover art images"
    }
  ) do
    if _1.show.album_cover.attached?
      Rails.application
          .routes
          .url_helpers
          .rails_blob_url(_1.show.album_cover)
    end
  end

  expose(
    :venue_slug,
    documentation: {
      type: "String",
      desc: "Unique slug of the venue where the show took place"
    }
  ) { _1.show.venue.slug }

  expose(
    :venue_name,
    documentation: {
      type: "String",
      desc: "Name the venue where the show took place, " \
            "reflecting the name used on the date of the show"
    }
  ) { _1.show.venue_name }

  expose(
    :venue_location,
    documentation: {
      type: "String",
      desc: "City and state where the venue of the show was located"
    }
  ) { _1.show.venue.location }

  expose \
    :show,
    using: ApiV2::Entities::Show,
    unless: ->(_, opts) { opts[:exclude_show] },
    documentation: {
      type: "Object",
      desc: "Show this track belongs to"
    }

  expose \
    :songs,
    documentation: {
      is_array: true,
      desc: "Songs associated with the track"
    } do |obj, opts|
      obj.songs.map do |song|
        songs_track = obj.songs_tracks.find { |st| st.song_id == song.id }
        ApiV2::Entities::Song.represent(song, opts.merge(songs_track:))
      end
  end

  expose :liked_by_user do
    unless _2[:liked_by_user].nil?
      _2[:liked_by_user]
    else
      _2[:liked_track_ids]&.include?(_1.id) || false
    end
  end
end
