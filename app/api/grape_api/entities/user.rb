class GrapeApi::Entities::User < GrapeApi::Entities::Base
  expose :username
  expose :email
  expose :created_at, format_with: :iso8601
end
