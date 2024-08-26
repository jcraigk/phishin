class ApiV2::Entities::TrackTag < ApiV2::Entities::Base
  expose \
    :name,
    documentation: {
      type: "String",
      desc: "The name of the tag"
    } do |track_tag|
      track_tag.tag.name
    end

  expose \
    :priority,
    documentation: {
      type: "Integer",
      desc: "The display priority of the tag"
    } do |track_tag|
      track_tag.tag.priority
    end

  expose \
    :notes,
    documentation: {
      type: "String",
      desc: "Optional notes related to this instance of the tag"
    }

  expose \
    :starts_at_second,
    documentation: {
      type: "Integer",
      desc: "The starting second of the tag within the track audio"
    }

  expose \
    :ends_at_second,
    documentation: {
      type: "Integer",
      desc: "The ending second of the tag within the track audio"
    }

  expose \
    :transcript,
    documentation: {
      type: "String",
      desc: "Transcript of the tagged portion of the track, if available"
    }
end
