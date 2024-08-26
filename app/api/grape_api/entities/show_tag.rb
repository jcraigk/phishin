module GrapeApi::Entities
  class ShowTag < Grape::Entity
    expose(:name) { |obj, _opts| obj.tag.name }
    expose(:priority) { |obj, _opts| obj.tag.priority }
    expose :notes
  end
end
