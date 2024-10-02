class ApiV2::Entities::PlaylistTrack < ApiV2::Entities::Base
  expose(
    :track,
    unless: ->(_, opts) { opts[:exclude_tracks] },
    documentation: {
      type: "Object",
      desc: "The associated track details"
    }
  ) do
    ApiV2::Entities::Track.represent \
      _1.track,
      _2.merge(exclude_show: true)
  end

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
      desc: \
        "Duration of track excerpt in milliseconds. If " \
        "starts_at_second and ends_at_second are both blank, " \
        "this will be the full duration of the track."
    }

  expose \
    :starts_at_second,
    documentation: {
      type: "Integer",
      desc: "If present, indicates the second at which to start playing the track"
    }

  expose \
    :ends_at_second,
    documentation: {
      type: "Integer",
      desc: "If present, indicates the second at which to stop playing the track"
    }
end
