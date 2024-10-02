class ApiV2::Entities::TrackTag < ApiV2::Entities::Base
  expose(
    :name,
    documentation: {
      type: "String",
      desc: "The name of the tag"
    }
   ) { _1.tag.name }

  expose(
    :description,
    documentation: {
      type: "String",
      desc: "A description of the tag"
    }
  ) { _1.tag.description }

  expose(
    :color,
    documentation: {
      type: "String",
      desc: "The color of the tag"
    }
  ) { _1.tag.color }

  expose(
    :priority,
    documentation: {
      type: "Integer",
      desc: "The display priority of the tag"
    }
  ) { _1.tag.priority }

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
