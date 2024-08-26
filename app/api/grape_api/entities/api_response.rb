class GrapeApi::Entities::ApiResponse < GrapeApi::Entities::Base
  expose :message, documentation: { type: "String", desc: "Error message" }
end
