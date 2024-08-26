class GrapeApi::Entities::ShowTag < GrapeApi::Entities::Base
  expose(:name) { |obj, _opts| obj.tag.name }
  expose(:priority) { |obj, _opts| obj.tag.priority }
  expose :notes
end
