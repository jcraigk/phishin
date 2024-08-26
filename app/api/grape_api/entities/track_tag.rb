class GrapeApi::Entities::TrackTag < GrapeApi::Entities::Base
  expose(:name) { _1.tag.name }
  expose(:priority) { _1.tag.priority }
  expose :notes
  expose :starts_at_second
  expose :ends_at_second
  expose :transcript
end
