class GrapeApi::Entities::ShowTag < GrapeApi::Entities::Base
  expose \
    :name,
    documentation: {
      type: "String",
      desc: "The name of the tag"
    } do |show_tag|
      show_tag.tag.name
    end

  expose \
    :priority,
    documentation: {
      type: "Integer",
      desc: "The display priority of the tag"
    } do |show_tag|
      show_tag.tag.priority
    end

  expose \
    :notes,
    documentation: {
      type: "String",
      desc: "Optional notes related to this instance of the tag"
    }
end
