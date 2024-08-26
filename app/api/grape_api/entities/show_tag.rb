class GrapeApi::Entities::ShowTag < GrapeApi::Entities::Base
  expose(:name) { _1.tag.name }
  expose(:priority) { _1.tag.priority }
  expose :notes
end
