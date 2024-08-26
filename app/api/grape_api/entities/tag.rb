class GrapeApi::Entities::Tag < GrapeApi::Entities::Base
  expose :slug
  expose :name
  expose :description
  expose :priority
  expose :shows_count
  expose :tracks_count
  expose :group
end
