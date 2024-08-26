class GrapeApi::Entities::Announcement < GrapeApi::Entities::Base
  expose :title
  expose :description
  expose :url
  expose :created_at, format_with: :iso8601
end
