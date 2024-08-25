module Api::V2::Entities
  class TrackTag < Grape::Entity
    expose(:name) { |obj, _opts| obj.tag.name }
    expose(:priority) { |obj, _opts| obj.tag.priority }
    expose :notes
    expose :starts_at_second
    expose :ends_at_second
    expose :transcript
  end
end
