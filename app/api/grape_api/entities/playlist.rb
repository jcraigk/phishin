class GrapeApi::Entities::Playlist < GrapeApi::Entities::Base
  expose :slug, documentation: { type: "String", desc: "The unique slug for the playlist" }
  expose :name, documentation: { type: "String", desc: "The name of the playlist" }
  expose(:username) { _1.user.username }
  expose :duration, documentation: { type: "Integer", desc: "The total duration of all tracks in the playlist" }
  expose :tracks, using: GrapeApi::Entities::Track, documentation: { type: "Array", desc: "The tracks in the playlist" } do |playlist|
    playlist.playlist_tracks.order(:position).map(&:track)
  end
  expose :track_count, documentation: { type: "Integer", desc: "The number of tracks in the playlist" } do |playlist|
    playlist.playlist_tracks.size
  end
  expose :updated_at,
            documentation: {
            type: "DateTime",
            desc: "The last update time of the playlist"
          }
end
