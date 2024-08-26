class ApiV2::Entities::ApiResponse < ApiV2::Entities::Base
  expose \
    :message,
    documentation: {
      type: "String",
      desc: "Error or success message"
    }
end
