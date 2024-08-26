class GrapeApi::Entities::Tag < GrapeApi::Entities::Base
  expose \
    :slug,
    documentation: {
      type: "String",
      desc: "Unique slug identifier for the tag"
    }

  expose \
    :name,
    documentation: {
      type: "String",
      desc: "Name of the tag"
    }

  expose \
    :description,
    documentation: {
      type: "String",
      desc: "Description of the tag"
    }

  expose \
    :priority,
    documentation: {
      type: "Integer",
      desc: "Priority level of the tag"
    }

  expose \
    :shows_count,
    documentation: {
      type: "Integer",
      desc: "Number of shows associated with the tag"
    }

  expose \
    :tracks_count,
    documentation: {
      type: "Integer",
      desc: "Number of tracks associated with the tag"
    }

  expose \
    :group,
    documentation: {
      type: "String",
      desc: "Group or category of the tag"
    }
end
