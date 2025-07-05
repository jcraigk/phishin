class ApiV2::Entities::Playlist < ApiV2::Entities::Base
  expose \
    :id,
    documentation: {
      type: "Integer",
      desc: "ID of the playlist"
    }

  expose \
    :slug,
    documentation: {
      type: "String",
      desc: "The unique slug for the playlist"
    }

  expose \
    :name,
    documentation: {
      type: "String",
      desc: "The display name of the playlist"
    }

  expose \
    :description,
    documentation: {
      type: "String",
      desc: "The description of the playlist"
    }

  expose(:username) { it.user.username }

  expose \
    :duration,
    documentation: {
      type: "Integer",
      desc: "The total duration of all tracks in the playlist, in milliseconds"
    }

  expose \
    :entries,
    using: ApiV2::Entities::PlaylistTrack,
    unless: ->(_, opts) { opts[:exclude_tracks] },
    documentation: {
      type: "Array",
      desc: \
        "The entries in the playlist, which themselves " \
        "include the track along with its position and other metadata"
    } do
      _1.playlist_tracks.order(:position)
    end

  expose \
    :tracks_count,
    documentation: {
      type: "Integer",
      desc: "The number of tracks in the playlist"
    }

  expose \
    :likes_count,
    documentation: {
      type: "Integer",
      desc: "The number of likes the playlist has received"
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
    :published,
    documentation: {
      type: "Boolean",
      desc: \
        "Indicates if the playlist is listed publicly " \
        "for other users to browse and search"
    }

  expose \
    :liked_by_user,
    documentation: {
      type: "Boolean",
      desc: "Indicates if the current user has liked this playlist"
    } do
      unless _2[:liked_by_user].nil?
        _2[:liked_by_user]
      else
        _2[:liked_playlist_ids]&.include?(_1.id) || false
      end
    end
end
