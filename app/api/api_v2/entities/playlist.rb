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

  expose(:username) { _1.user.username }

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
    } do |obj|
      obj.playlist_tracks.order(:position)
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
    :updated_at,
    documentation: {
      type: "String",
      desc: "The last update time of the playlist"
    }

  expose \
    :published,
    documentation: {
      type: "Boolean",
      desc: \
        "Indicates if the playlist is listed publicly " \
        "for other users to browse and search"
    }

  expose(
      :liked_by_user
    ) do |obj, opts|
      unless opts[:liked_by_user].nil?
        opts[:liked_by_user]
      else
        opts[:liked_playlist_ids]&.include?(obj.id) || false
      end
    end
end
