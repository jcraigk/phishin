class ApiV2::Entities::ShowTag < ApiV2::Entities::Base
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
end
