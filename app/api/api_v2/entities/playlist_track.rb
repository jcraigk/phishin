class ApiV2::Entities::PlaylistTrack < ApiV2::Entities::Base
  expose(
    :track,
    documentation: {
      type: "Object",
      desc: "The associated track details"
    }
  ) do |obj, opts|
    ApiV2::Entities::Track.represent \
      obj.track,
      opts.merge(exclude_show: true)
  end

  expose \
    :position,
    documentation: {
      type: "Integer",
      desc: "Position of the track in the setlist"
    }

  expose(
    :duration,
    documentation: {
      type: "Integer",
      desc: \
        "Duration of track excerpt in milliseconds if " \
        "starts_at_second and/or ends_at_second is present"
    }) do |obj|
      start_second = obj.starts_at_second.to_i
      end_second = obj.ends_at_second.to_i
      if start_second <= 0 && end_second <= 0
        obj.track.duration
      elsif start_second > 0 && end_second > 0
        (end_second - start_second) * 1000
      elsif start_second > 0
        (obj.track.duration / 1000 - start_second) * 1000
      elsif end_second > 0
        end_second * 1000
      end
    end

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
